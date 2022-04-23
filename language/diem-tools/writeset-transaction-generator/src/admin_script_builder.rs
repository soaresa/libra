// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0
use std::{time::{SystemTime, UNIX_EPOCH}, fs};

use anyhow::{Result, bail};
use cli::client_proxy::encode_stdlib_upgrade_transaction;
use diem_transaction_replay::DiemDebugger;
use diem_types::{
    account_address::AccountAddress,
    account_config::{self, diem_root_address, NewEpochEvent},
    transaction::{ChangeSet, Script, TransactionArgument, WriteSetPayload}, contract_event::ContractEvent,
};

use handlebars::Handlebars;
use move_core_types::{
    identifier::Identifier,
    language_storage::{ModuleId, TypeTag},
    transaction_argument::convert_txn_args,
    value::{serialize_values, MoveValue},
};

use move_lang::{compiled_unit::CompiledUnit, shared::Flags};
use move_vm_runtime::logging::NoContextLog;
use move_vm_types::gas_schedule::GasStatus;
use ol_types::epoch_timer::EpochTimerResource;
use serde::{Serialize, Deserialize};
use std::{collections::HashMap, io::Write, path::PathBuf, process::exit};
use tempfile::NamedTempFile;
use resource_viewer::AnnotatedMoveValue;
use move_core_types::move_resource::MoveStructType;

/// The relative path to the scripts templates
pub const SCRIPTS_DIR_PATH: &str = "templates";

pub fn compile_script(source_file_str: String) -> Vec<u8> {
    let (_files, mut compiled_program) = move_lang::move_compile_and_report(
        &[source_file_str],
        &diem_framework::diem_stdlib_files(),
        None,
        Flags::empty().set_sources_shadow_deps(false),
    )
    .unwrap();
    let mut script_bytes = vec![];
    assert!(compiled_program.len() == 1);
    match compiled_program.pop().unwrap() {
        CompiledUnit::Module { .. } => panic!("Unexpected module when compiling script"),
        CompiledUnit::Script { script, .. } => script.serialize(&mut script_bytes).unwrap(),
    };
    script_bytes
}

fn compile_admin_script(input: &str) -> Result<Script> {
    let mut temp_file = NamedTempFile::new()?;
    temp_file.write_all(input.as_bytes())?;
    let cur_path = temp_file.path().to_str().unwrap().to_owned();
    Ok(Script::new(compile_script(cur_path), vec![], vec![]))
}

pub fn template_path() -> PathBuf {
    let mut path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    path.push(SCRIPTS_DIR_PATH.to_string());
    path
}

pub fn encode_remove_validators_payload(validators: Vec<AccountAddress>) -> WriteSetPayload {
    assert!(!validators.is_empty(), "Unexpected validator set length");
    let mut script = template_path();
    script.push("remove_validators.move");

    let script = {
        let mut hb = Handlebars::new();
        hb.set_strict_mode(true);
        hb.register_template_file("script", script).unwrap();
        let mut data = HashMap::new();
        data.insert("addresses", validators);

        let output = hb.render("script", &data).unwrap();

        compile_admin_script(output.as_str()).unwrap()
    };

    WriteSetPayload::Script {
        script,
        execute_as: diem_root_address(),
    }
}

pub fn encode_custom_script<T: Serialize>(
    script_name_in_templates: &str,
    args: &T,
    execute_as: Option<AccountAddress>,
) -> WriteSetPayload {
    let mut script = template_path();
    script.push(script_name_in_templates);

    let script = {
        let mut hb = Handlebars::new();
        hb.register_template_file("script", script).unwrap();
        hb.set_strict_mode(true);
        let output = hb.render("script", args).unwrap();

        compile_admin_script(output.as_str()).unwrap()
    };

    WriteSetPayload::Script {
        script,
        execute_as: execute_as.unwrap_or_else(diem_root_address),
    }
}

pub fn encode_halt_network_payload() -> WriteSetPayload {
    let mut script = template_path();
    script.push("halt_transactions.move");

    WriteSetPayload::Script {
        script: Script::new(
            compile_script(script.to_str().unwrap().to_owned()),
            vec![],
            vec![],
        ),
        execute_as: diem_root_address(),
    }
}

//////// 0L ////////
pub fn script_bulk_update_vals_payload(vals: Vec<AccountAddress>) -> WriteSetPayload {
    println!("\nencode_bulk_update_vals_payload");
    let mut script = template_path();
    script.push("bulk_update.move");

    WriteSetPayload::Script {
        script: Script::new(
            compile_script(script.to_str().unwrap().to_owned()),
            vec![],
            vec![TransactionArgument::AddressVector(vals)],
        ),
        execute_as: diem_root_address(),
    }
}
/// Force the ol epoch boundary and reset all the counters
/// TODO: this creates some issue for block_prologue around epoch boundary because data disappears.
pub fn ol_writeset_force_boundary(path: PathBuf, vals: Vec<AccountAddress>) -> WriteSetPayload {
    let cs = ol_force_boundary(path, vals).unwrap();
    WriteSetPayload::Direct(cs)
}

pub fn ol_debug(path: PathBuf) -> WriteSetPayload {
  WriteSetPayload::Direct(ol_debug_height(path).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_stdlib_upgrade(path: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let stdlib_cs = encode_stdlib_upgrade_transaction();

    let reconfig = ol_reconfig_changeset(path).unwrap();

    WriteSetPayload::Direct(merge_change_set(stdlib_cs, reconfig).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_set_stagingnet(path: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let testnet = ol_staging_net_changeset(path.clone()).unwrap();

    let reconfig = ol_reconfig_changeset(path).unwrap();

    WriteSetPayload::Direct(merge_change_set(testnet, reconfig).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_set_testnet(path: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let testnet = ol_testnet_changeset(path.clone()).unwrap();

    let reconfig = ol_reconfig_changeset(path).unwrap();

    WriteSetPayload::Direct(merge_change_set(testnet, reconfig).unwrap())
}


/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_mfg_epoch_event(path: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let stdlib_cs = ol_testnet_changeset(path.clone()).unwrap();

    let epoch_event = mfg_epoch_event(168, 168).unwrap();

    let cs = ChangeSet::new(stdlib_cs.write_set().clone(), vec!(epoch_event));

    WriteSetPayload::Direct(cs)
}


/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_ancestry(path: PathBuf, ancestry_file: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let cs = ol_ancestry_migrate(
      path.clone(), 
      parse_ancestry_file(ancestry_file).unwrap()
    ).unwrap();
    WriteSetPayload::Direct(cs)

}


fn parse_ancestry_file(ancestry_file: PathBuf) -> Result<Vec<AncestrysUnit>>{
    let file = fs::File::open(ancestry_file).expect("file should open read only");

    let ancestry_vec: Vec<AncestrysUnit> = serde_json::from_reader(file).expect("file should be proper JSON");
    Ok(ancestry_vec)
}

fn parse_makewhole_file(makewhole_file: PathBuf) -> Result<Vec<MakeWholeUnit>>{
    let file = fs::File::open(makewhole_file).expect("file should open read only");

    let makewhole_vec: Vec<MakeWholeUnit> = serde_json::from_reader(file).expect("file should be proper JSON");
    Ok(makewhole_vec)
}

pub fn ol_writset_encode_rescue(path: PathBuf, vals: Vec<AccountAddress>) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    let stdlib_cs = ol_fresh_stlib_changeset(path.clone()).unwrap();
    // TODO: forcing the boundary causes an error on the epoch boundary.
    let boundary = ol_bulk_validators_changeset(path.clone(), vals).unwrap();
    // let boundary = ol_bulk_validators_changeset(path.clone(), vals).unwrap();

    // let new_cs = merge_change_set(stdlib_cs, boundary).unwrap();
    let new_cs = merge_vec_changeset(vec![stdlib_cs, boundary]).unwrap();
    // WriteSetPayload::Direct(merge_change_set(new_cs, time).unwrap())
    WriteSetPayload::Direct(new_cs)
}

pub fn ol_writset_encode_migrations(
  path: PathBuf,
  ancestry_file: PathBuf,
  makewhole_file: PathBuf,
  vals: Vec<AccountAddress>
) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    let ancestry = ol_ancestry_migrate(
      path.clone(), 
      parse_ancestry_file(ancestry_file).unwrap()
    ).unwrap();

    let makewhole = ol_makewhole_migrate(
      path.clone(), 
      parse_makewhole_file(makewhole_file).unwrap()
    ).unwrap();

    let vouch = ol_vouch_migrate(path.clone(), vals.clone()).unwrap();

    // force an NewEpochEvent
    let boundary = ol_bulk_validators_changeset(path.clone(), vals.clone()).unwrap();

    // let new_cs = merge_change_set(stdlib_cs, boundary).unwrap();
    let new_cs = merge_vec_changeset(vec![ancestry, makewhole, vouch, boundary]).unwrap();
    // WriteSetPayload::Direct(merge_change_set(new_cs, time).unwrap())
    WriteSetPayload::Direct(new_cs)
}


/// set the EpochBoundary debug mode.
pub fn ol_writeset_debug_epoch(path: PathBuf, vals: Vec<AccountAddress>) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    let debug_mode = ol_set_epoch_debug_mode(path.clone(), vals).unwrap();
    let reconfig = ol_reconfig_changeset(path).unwrap();

    WriteSetPayload::Direct(merge_change_set(debug_mode, reconfig).unwrap())
}

pub fn ol_writset_update_timestamp(path: PathBuf) -> WriteSetPayload {
    let timestamp = ol_increment_timestamp(path.clone()).expect("could not get timestamp writeset");

    // Take the stdlib upgrade change set.
    let reconfig = ol_reconfig_changeset(path).expect("could not get reconfig writeset");

    WriteSetPayload::Direct(merge_change_set(timestamp, reconfig).unwrap())
}

pub fn ol_create_reconfig_payload(path: PathBuf) -> WriteSetPayload {
    WriteSetPayload::Direct(
        ol_reconfig_changeset(path).expect("could not create reconfig change set"),
    )
}


pub fn ol_writeset_update_epoch_time(path: PathBuf) -> WriteSetPayload {

    let epoch_time = ol_epoch_timestamp_update(path.clone()).unwrap();
    let reconfig = ol_reconfig_changeset(path).unwrap();

    WriteSetPayload::Direct(merge_change_set(epoch_time, reconfig).unwrap())
}

///////////////// ENCODE CHANGESETS ///////////////////////////////


pub fn ol_fresh_stlib_changeset(path: PathBuf) -> Result<ChangeSet> {
    println!("\nencode stdlib changeset");

    let db = DiemDebugger::db(path)?;

    // publish the agreed stdlib
    let new_stdlib = diem_framework::modules();

    let v = db.get_latest_version()?;
    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        for module in new_stdlib {
            let mut bytes = vec![];
            module.serialize(&mut bytes).unwrap();

            session
                .revise_module(
                    bytes,
                    account_config::CORE_CODE_ADDRESS,
                    &mut gas_status,
                    &log_context,
                )
                .unwrap()
        }
        Ok(())
    })
}

// NOTE: all new "genesis" writesets to be applied on db-bootstrapper must emit a reconfig NewEpochEvent.
// However. The Diemconfig::reconfig_ has a naive implementation of deduplication of reconfig events it checks that the current time is NOT equal to the last reconfig time.
// For db backups/snapshots using the backup-cli, the archives are generally made at an epoch boundary. And as such the timestamp will be identical to the last reconfiguration time, and ANY WRITESET USING DB-BOOTSTRAPPER WILL FAIL.
// This function is used to force a new timestamp in those cases, so that writesets will trigger reconfigs (if that is what is expected/intended).

fn _ol_increment_timestamp_changeset(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    let start = SystemTime::now();
    let now = start.duration_since(UNIX_EPOCH)?;
    let microseconds = now.as_micros();

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let txn_args = vec![
            TransactionArgument::Address(diem_root_address()),
            TransactionArgument::Address("46A7A744B5D33C47F6B20766F8088B10".parse().unwrap()),
            TransactionArgument::U64(microseconds as u64),
        ];
        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("DiemTimestamp").unwrap(),
                ),
                &Identifier::new("update_global_time").unwrap(),
                vec![],
                convert_txn_args(&txn_args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // todo remove this unwrap.

        Ok(())
    })
}


fn ol_increment_timestamp(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    let start = SystemTime::now();
    let now = start.duration_since(UNIX_EPOCH)?;
    let microseconds = now.as_micros();

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let txn_args = vec![
            TransactionArgument::Address(diem_root_address()),
            TransactionArgument::Address(AccountAddress::random()),
            TransactionArgument::U64(microseconds as u64),
        ];
        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("DiemTimestamp").unwrap(),
                ),
                &Identifier::new("update_global_time").unwrap(),
                vec![],
                convert_txn_args(&txn_args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // todo remove this unwrap.
        
        let args = vec![MoveValue::Signer(diem_root_address())];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("DiemConfig").unwrap(),
                ),
                &Identifier::new("upgrade_reconfig").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}



fn _ol_autopay_migrate(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    let start = SystemTime::now();
    let now = start.duration_since(UNIX_EPOCH)?;
    let _microseconds = now.as_micros();

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let args = vec![MoveValue::Signer(diem_root_address())];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("MigrateAutoPayBal").unwrap(),
                ),
                &Identifier::new("do_it").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}

fn ol_vouch_migrate(path: PathBuf, val_set: Vec<AccountAddress>) -> Result<ChangeSet> {
    println!("\nmigrating validator vouch data");
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    let start = SystemTime::now();
    let now = start.duration_since(UNIX_EPOCH)?;
    let _microseconds = now.as_micros();

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        val_set.clone().iter()
        .for_each(|addr| {
          let args = vec![MoveValue::Signer(addr.to_owned())];

          session
              .execute_function(
                  &ModuleId::new(
                      account_config::CORE_CODE_ADDRESS,
                      Identifier::new("Vouch").unwrap(),
                  ),
                  &Identifier::new("init").unwrap(),
                  vec![],
                  serialize_values(&args),
                  &mut gas_status,
                  &log_context,
              )
              .unwrap(); // TODO: don't use unwraps.

          let args = vec![
            MoveValue::Signer(diem_root_address()),
            MoveValue::Address(addr.to_owned()),
            MoveValue::vector_address(val_set.clone()),

          ];

          session
              .execute_function(
                  &ModuleId::new(
                      account_config::CORE_CODE_ADDRESS,
                      Identifier::new("Vouch").unwrap(),
                  ),
                  &Identifier::new("vm_migrate").unwrap(),
                  vec![],
                  serialize_values(&args),
                  &mut gas_status,
                  &log_context,
              )
              .unwrap(); // TODO: don't use unwraps.

          });
          
        Ok(())
    })
}

#[derive(Debug, Serialize, Deserialize)]
struct MakeWholeUnit {
  address: AccountAddress,
  value: f64,
}

fn ol_makewhole_migrate(path: PathBuf, payments: Vec<MakeWholeUnit>) -> Result<ChangeSet> {
    println!("\nmigrating make whole data");
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        payments.iter()
        .for_each(|p| {

        let scaled = f64::trunc(p.value * 1000000f64) as u64;

        let args = vec![
          MoveValue::Signer(diem_root_address()),
          MoveValue::Signer(p.address),
          MoveValue::U64(scaled),
          MoveValue::vector_u8("carpe underpayment".as_bytes().to_vec()),
        ];
        
        session
          .execute_function(
              &ModuleId::new(
                  account_config::CORE_CODE_ADDRESS,
                  Identifier::new("MakeWhole").unwrap(),
              ),
              &Identifier::new("vm_offer_credit").unwrap(),
              vec![],
              serialize_values(&args),
              &mut gas_status,
              &log_context,
          )
          .unwrap(); // TODO: don't use unwraps.
        });

        Ok(())
    })
}

#[derive(Debug, Serialize, Deserialize)]
struct AncestrysUnit {
  account: AccountAddress,
  ancestry: Vec<AccountAddress>,
}
fn ol_ancestry_migrate(path: PathBuf, ancestry_vec: Vec<AncestrysUnit> ) -> Result<ChangeSet> {
    println!("\nmigrating ancestry data");

    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        ancestry_vec.into_iter()
        .for_each(|a| {
        let args = vec![
          MoveValue::Signer(diem_root_address()),
          MoveValue::Address(a.account),
          MoveValue::vector_address(a.ancestry),
        ];

        session
        .execute_function(
            &ModuleId::new(
                account_config::CORE_CODE_ADDRESS,
                Identifier::new("Ancestry").unwrap(),
            ),
            &Identifier::new("migrate").unwrap(),
            vec![],
            serialize_values(&args),
            &mut gas_status,
            &log_context,
        )
        .unwrap(); // TODO: don't use unwraps.
        });



        Ok(())
    })
}


fn ol_epoch_timestamp_update(path: PathBuf) -> Result<ChangeSet>{
  let db = DiemDebugger::db(path)?;
  let v = db.get_latest_version()?;

  let start = SystemTime::now();
  let now = start.duration_since(UNIX_EPOCH)?;
  let microseconds_now = now.as_micros();

  if let Some(acc) = db.annotate_account_state_at_version(AccountAddress::ZERO, v, false)? {
    let key = EpochTimerResource::struct_tag();
    // confirm the field exists.
    if let Some(v) = acc.0.get(&key) {
      // dbg!(&v);
      let mut e = EpochTimerResource {
          epoch: 0,
          height_start: 0,
          seconds_start: microseconds_now as u64,
      };

      v.value.iter()
      .for_each(|item| {
        if let AnnotatedMoveValue::U64(u) = item.1 {
          match item.0.as_str() {
            "epoch" => e.epoch = u,
            "height_start" => e.height_start = u,
            // "seconds_start" => e.seconds_start = u,
            _ => {}
          }
        };
      });
      
      dbg!(&e);
      let cs = ChangeSet::new(e.to_writeset()?.freeze()?, vec![]);
      return Ok(cs);

    }
  };

  bail!("could not get epoch timer state")
}

#[test]
fn test_epoch() {
  ol_epoch_timestamp_update("/home/node/.0L/db".parse().unwrap());
}

fn ol_set_epoch_debug_mode(path: PathBuf, vals: Vec<AccountAddress>) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;
    let v = db.get_latest_version()?;

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let txn_args = vec![
            TransactionArgument::Address(diem_root_address()),
            TransactionArgument::AddressVector(vals),
        ];
        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("EpochBoundary").unwrap(),
                ),
                &Identifier::new("init_debug").unwrap(),
                vec![],
                convert_txn_args(&txn_args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // todo remove this unwrap.
        Ok(())
    })
}

fn ol_bulk_validators_changeset(path: PathBuf, vals: Vec<AccountAddress>) -> Result<ChangeSet> {
    println!("\nencode validators bulk update changeset");
    let db = DiemDebugger::db(path)?;

    let v = db.get_latest_version()?;
    dbg!(&v);
    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let txn_args = vec![
            TransactionArgument::Address(diem_root_address()),
            TransactionArgument::AddressVector(vals),
        ];
        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("DiemSystem").unwrap(),
                ),
                &Identifier::new("bulk_update_validators").unwrap(),
                vec![],
                convert_txn_args(&txn_args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // todo remove this unwrap.
        Ok(())
    })
}

fn ol_reconfig_changeset(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;

    let v = db.get_latest_version()?;
    let cs = db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let args = vec![MoveValue::Signer(diem_root_address())];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("Upgrade").unwrap(),
                ),
                &Identifier::new("upgrade_reconfig").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })?;
    // dbg!(&cs.events().len());
    
    let old_event = cs.events().first().unwrap();
    let epoch_change = read_epoch_event(&cs)?;

    let new_ce = mfg_epoch_event(epoch_change.epoch(), old_event.sequence_number())?;

    let new_change_set = ChangeSet::new(cs.write_set().to_owned(), vec![new_ce]);
    
    new_change_set.events().iter()
    .for_each(|e|{
      // dbg!(&e);
      dbg!(&e.sequence_number());

    });

    Ok(cs)
  }

fn mfg_epoch_event(epoch: u64, seq: u64) -> Result<ContractEvent>{
    let new_event = NewEpochEvent::new(epoch);
    
    dbg!(&new_event.epoch());

    Ok( 
      ContractEvent::new(
        NewEpochEvent::event_key(),
        seq,
        TypeTag::Struct(NewEpochEvent::struct_tag()),
        bcs::to_bytes(&new_event)?,
      )
    )
}

fn read_epoch_event(cs: &ChangeSet) -> Result<NewEpochEvent> {
  let event = cs.events().first().unwrap();
  NewEpochEvent::try_from_bytes(event.event_data())
}

fn ol_testnet_changeset(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;

    let v = db.get_latest_version()?;
    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let args = vec![MoveValue::Signer(diem_root_address())];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("Testnet").unwrap(),
                ),
                &Identifier::new("initialize").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}

fn ol_staging_net_changeset(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;

    let v = db.get_latest_version()?;
    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        let args = vec![MoveValue::Signer(diem_root_address())];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("StagingNet").unwrap(),
                ),
                &Identifier::new("initialize").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}

// TODO this doesn't work.
fn ol_force_boundary(path: PathBuf, vals: Vec<AccountAddress>) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;

    // TODO: This is not producing the same version height after appling to database.
    let v = db.get_latest_version()?;

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        // fun reset_counters(vm: &signer, proposed_set: vector<address>, outgoing_compliant: vector<address>, height_now: u64) {

        let args = vec![
            MoveValue::Signer(diem_root_address()),
            MoveValue::vector_address(vals),   // proposed_set
            MoveValue::vector_address(vec![]), // outgoing_compliant
            MoveValue::U64(v),                 // height_now
        ];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("EpochBoundary").unwrap(),
                ),
                &Identifier::new("reset_counters").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}


// TODO this doesn't work.
fn ol_debug_height(path: PathBuf) -> Result<ChangeSet> {
    let db = DiemDebugger::db(path)?;

    // TODO: This is not producing the same version height after appling to database.
    let v = db.get_latest_version()?;

    db.run_session_at_version(v, None, |session| {
        let mut gas_status = GasStatus::new_unmetered();
        let log_context = NoContextLog::new();

        // fun reset_counters(vm: &signer, proposed_set: vector<address>, outgoing_compliant: vector<address>, height_now: u64) {

        let args = vec![
           MoveValue::U64(v)              // height_now
        ];

        session
            .execute_function(
                &ModuleId::new(
                    account_config::CORE_CODE_ADDRESS,
                    Identifier::new("DiemBlock").unwrap(),
                ),
                &Identifier::new("debug_height_version").unwrap(),
                vec![],
                serialize_values(&args),
                &mut gas_status,
                &log_context,
            )
            .unwrap(); // TODO: don't use unwraps.
        Ok(())
    })
}


 ///////////// HELPERS ////////////
  
fn merge_vec_changeset(mut vec_cs: Vec<ChangeSet>) -> Result<ChangeSet> {
  let mut new_cs= vec_cs.pop().unwrap();

  vec_cs.into_iter()
    .for_each(|c| {
      new_cs = merge_change_set(new_cs.clone(), c).unwrap();
    });
  
  Ok(new_cs)
}
fn merge_change_set(left: ChangeSet, right: ChangeSet) -> Result<ChangeSet> {
    // get stlib_cs writeset mut and apply reconfig changeset over it
    let mut stdlib_ws_mut = left.write_set().clone().into_mut();

    let r_ws = right.write_set().clone().into_mut();

    r_ws.get()
        .into_iter()
        .for_each(|item| stdlib_ws_mut.push(item));

    let mut all_events = left.events().to_owned().clone();
    let mut reconfig_events = right.events().to_owned().clone();
    all_events.append(&mut reconfig_events);

    let new_cs = ChangeSet::new(stdlib_ws_mut.freeze()?, all_events);

    Ok(new_cs)
}