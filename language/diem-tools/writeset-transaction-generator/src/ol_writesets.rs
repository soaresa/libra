// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use cli::client_proxy::encode_stdlib_upgrade_transaction;

use diem_types::{
    account_address::AccountAddress,
    transaction::{ChangeSet, WriteSetPayload},
};

use std::{path::PathBuf, process::exit};

use crate::ol_changesets::{
    migrations,
    reconfig::{self, ol_increment_timestamp},
    stdlib, testnet,
};

/// Force the ol epoch boundary and reset all the counters
/// TODO: this creates some issue for block_prologue around epoch boundary because data disappears.
pub fn ol_writeset_force_boundary(
    path: PathBuf,
    vals: Vec<AccountAddress>,
    block_height: u64,
) -> WriteSetPayload {
    let cs = reconfig::ol_reset_epoch_counters(path, vals, block_height).unwrap();
    WriteSetPayload::Direct(cs)
}

// pub fn ol_debug(path: PathBuf) -> WriteSetPayload {
//   WriteSetPayload::Direct(ol_debug_height(path).unwrap())
// }

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_stdlib_upgrade(path: PathBuf, height_now: u64) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let stdlib_cs = encode_stdlib_upgrade_transaction();

    let reconfig = reconfig::ol_reconfig_changeset(path, height_now).unwrap();

    WriteSetPayload::Direct(merge_change_set(stdlib_cs, reconfig).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_set_stagingnet(path: PathBuf, height_now: u64) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let testnet = testnet::ol_staging_net_changeset(path.clone()).unwrap();

    let reconfig = reconfig::ol_reconfig_changeset(path, height_now).unwrap();

    WriteSetPayload::Direct(merge_change_set(testnet, reconfig).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_set_testnet(path: PathBuf, height_now: u64) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let testnet = testnet::ol_testnet_changeset(path.clone()).unwrap();

    let reconfig = reconfig::ol_reconfig_changeset(path, height_now).unwrap();

    WriteSetPayload::Direct(merge_change_set(testnet, reconfig).unwrap())
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_mfg_epoch_event(path: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let stdlib_cs = testnet::ol_testnet_changeset(path.clone()).unwrap();

    let epoch_event = reconfig::mfg_epoch_event(168, 168).unwrap();

    let cs = ChangeSet::new(stdlib_cs.write_set().clone(), vec![epoch_event]);

    WriteSetPayload::Direct(cs)
}

/// create the upgrade payload INCLUDING the epoch reconfigure
pub fn ol_writeset_ancestry(path: PathBuf, ancestry_file: PathBuf) -> WriteSetPayload {
    // Take the stdlib upgrade change set.
    let cs = migrations::ol_ancestry_migrate(
        path.clone(),
        migrations::parse_ancestry_file(ancestry_file).unwrap(),
    )
    .unwrap();
    WriteSetPayload::Direct(cs)
}

// /// create the upgrade payload INCLUDING the epoch reconfigure
// pub fn ol_writeset_hotfix(path: PathBuf, vals: Vec<AccountAddress>, recovery_epoch: u64) -> WriteSetPayload {
//     // Take the stdlib upgrade change set.
//     let cumu_deps = ol_cumu_deposits_hotfix(path.clone()).unwrap();

//     let recovery = stdlib::ol_set_epoch_recovery_mode(path.clone(), vec![], recovery_epoch).unwrap();

//     let boundary = ol_bulk_validators_changeset(path.clone(), vals).unwrap();

//     let new_cs = merge_vec_changeset(vec![cumu_deps, recovery, boundary]).unwrap();

//     WriteSetPayload::Direct(new_cs)

// }

pub fn ol_writset_encode_rescue(path: PathBuf, vals: Vec<AccountAddress>) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    let stdlib_cs = stdlib::ol_fresh_stlib_changeset(path.clone()).unwrap();
    // TODO: forcing the boundary causes an error on the epoch boundary.
    // let boundary = ol_force_boundary(path.clone(), vals.clone(), block_height).unwrap();
    let boundary = reconfig::ol_bulk_validators_changeset(path.clone(), vals).unwrap();

    // set recovery mode

    // let new_cs = merge_change_set(stdlib_cs, boundary).unwrap();
    let new_cs = merge_vec_changeset(vec![stdlib_cs, boundary]).unwrap();
    // WriteSetPayload::Direct(merge_change_set(new_cs, time).unwrap())
    WriteSetPayload::Direct(new_cs)
}

pub fn ol_writset_encode_migrations(
    path: PathBuf,
    ancestry_file: PathBuf,
    makewhole_file: PathBuf,
    vals: Vec<AccountAddress>,
    block_height: u64,
    recovery_epoch: u64,
) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    let ancestry = migrations::ol_ancestry_migrate(
        path.clone(),
        migrations::parse_ancestry_file(ancestry_file).unwrap(),
    )
    .unwrap();

    let makewhole = migrations::ol_makewhole_migrate(
        path.clone(),
        migrations::parse_makewhole_file(makewhole_file).unwrap(),
    )
    .unwrap();

    let vouch = migrations::ol_vouch_migrate(path.clone(), vals.clone()).unwrap();

    // Note: passing an emptry vec for vals will preserve validator selection logic. To create a fixed validator set for recovery modify this code to pass a list of validators.
    let recovery =
        stdlib::ol_set_epoch_recovery_mode(path.clone(), vec![], recovery_epoch).unwrap();

    let boundary = reconfig::ol_reset_epoch_counters(path.clone(), vals, block_height).unwrap();

    // let new_cs = merge_change_set(stdlib_cs, boundary).unwrap();
    let new_cs = merge_vec_changeset(vec![ancestry, makewhole, vouch, boundary, recovery]).unwrap();
    // WriteSetPayload::Direct(merge_change_set(new_cs, time).unwrap())
    WriteSetPayload::Direct(new_cs)
}

/// set the EpochBoundary debug mode.
pub fn ol_writeset_recovery_mode(
    path: PathBuf,
    vals: Vec<AccountAddress>,
    epoch_ending: u64,
) -> WriteSetPayload {
    if vals.len() == 0 {
        println!("need to provide list of addresses");
        exit(1)
    };

    // Note: passing an emptry vec for vals will preserve validator selection logic. To create a fixed validator set for recovery modify this code to pass a list of validators.
    let recovery_mode =
        stdlib::ol_set_epoch_recovery_mode(path.clone(), vec![], epoch_ending).unwrap();
    let reconfig = reconfig::ol_bulk_validators_changeset(path, vals).unwrap();

    WriteSetPayload::Direct(merge_change_set(recovery_mode, reconfig).unwrap())
}

pub fn ol_writset_update_timestamp(path: PathBuf, height_now: u64) -> WriteSetPayload {
    let timestamp = ol_increment_timestamp(path.clone()).expect("could not get timestamp writeset");

    // Take the stdlib upgrade change set.
    let reconfig =
        reconfig::ol_reconfig_changeset(path, height_now).expect("could not get reconfig writeset");

    WriteSetPayload::Direct(merge_change_set(timestamp, reconfig).unwrap())
}

pub fn ol_create_reconfig_payload(path: PathBuf, height_now: u64) -> WriteSetPayload {
    WriteSetPayload::Direct(
        reconfig::ol_reconfig_changeset(path, height_now)
            .expect("could not create reconfig change set"),
    )
}

pub fn ol_writeset_update_epoch_time(path: PathBuf, height_now: u64) -> WriteSetPayload {
    let epoch_time = reconfig::ol_epoch_timestamp_update(path.clone()).unwrap();
    let reconfig = reconfig::ol_reconfig_changeset(path, height_now).unwrap();

    WriteSetPayload::Direct(merge_change_set(epoch_time, reconfig).unwrap())
}

///////////// HELPERS ////////////

fn merge_vec_changeset(mut vec_cs: Vec<ChangeSet>) -> Result<ChangeSet> {
    let mut new_cs = vec_cs.pop().unwrap();

    vec_cs.into_iter().for_each(|c| {
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
