///////////////////////////////////////////////////////////////////////////
// 0L Module
// Epoch Boundary
///////////////////////////////////////////////////////////////////////////
// The prologue for transitioning to next epoch after every n blocks.
// File Prefix for errors: 1800
///////////////////////////////////////////////////////////////////////////


address 0x1 {
module EpochBoundary {
    use 0x1::CoreAddresses;
    use 0x1::Subsidy;
    use 0x1::NodeWeight;
    use 0x1::DiemSystem;
    use 0x1::TowerState;
    use 0x1::Globals;
    use 0x1::Vector;
    use 0x1::Stats;
    use 0x1::AutoPay;
    use 0x1::Epoch;
    use 0x1::DiemConfig;
    use 0x1::Audit;
    use 0x1::DiemAccount;
    use 0x1::Burn;
    use 0x1::FullnodeSubsidy;
    use 0x1::ValidatorUniverse;
    use 0x1::Testnet;
    use 0x1::StagingNet;
    use 0x1::RecoveryMode;
    use 0x1::Cases;

    use 0x1::Debug::print;



    // This function is called by block-prologue once after n blocks.
    // Function code: 01. Prefix: 180001
    public fun reconfigure(vm: &signer, height_now: u64) {

        CoreAddresses::assert_vm(vm);
        let height_start = Epoch::get_timer_height_start(vm);
        print(&800100);
        let (outgoing_compliant_set, _) = 
            DiemSystem::get_fee_ratio(vm, height_start, height_now);
        print(&800200);

        // NOTE: This is "nominal" because it doesn't check
        let compliant_nodes_count = Vector::length(&outgoing_compliant_set);
        print(&800300);

        let (subsidy_units, nominal_subsidy_per) = 
            Subsidy::calculate_subsidy(vm, compliant_nodes_count);
        print(&800400);
        process_fullnodes(vm, nominal_subsidy_per);
        print(&800500);

        process_validators(vm, subsidy_units, *&outgoing_compliant_set);
        print(&800600);

        let proposed_set = propose_new_set(vm, height_start, height_now);
        print(&800700);

        // Update all slow wallet limits
        DiemAccount::slow_wallet_epoch_drip(vm, Globals::get_unlock());
        print(&800800);

        if (!RecoveryMode::is_recovery()) {
          proof_of_burn(vm,nominal_subsidy_per, &proposed_set);
          print(&800900);
        };


        reset_counters(vm, proposed_set, outgoing_compliant_set, height_now);
        print(&801000);

    }

    // process fullnode subsidy
    fun process_fullnodes(vm: &signer, nominal_subsidy_per_node: u64) {
        // Fullnode subsidy
        // loop through validators and pay full node subsidies.
        // Should happen before transactionfees get distributed.
        // Note: need to check, there may be new validators which have not mined yet.
        let miners = TowerState::get_miner_list();
        // fullnode subsidy is a fraction of the total subsidy available to validators.
        let proof_price = FullnodeSubsidy::get_proof_price(nominal_subsidy_per_node);

        let k = 0;
        // Distribute mining subsidy to fullnodes
        while (k < Vector::length(&miners)) {
            let addr = *Vector::borrow(&miners, k);
            if (DiemSystem::is_validator(addr)) { // skip validators
              k = k + 1;
              continue
            };
            
            // TODO: this call is repeated in propose_new_set. 
            // Not sure if the performance hit at epoch boundary is worth the refactor. 
            if (TowerState::node_above_thresh(addr)) {
              let count = TowerState::get_count_above_thresh_in_epoch(addr);

              let miner_subsidy = count * proof_price;

              // don't pay while we are in recovery mode, since that creates a frontrunning opportunity
              if (!RecoveryMode::is_recovery()){ 
                FullnodeSubsidy::distribute_fullnode_subsidy(vm, addr, miner_subsidy);
              }
              
            };

            k = k + 1;
        };
    }

    fun process_validators(
        vm: &signer, subsidy_units: u64, outgoing_compliant_set: vector<address>
    ) {
        // Process outgoing validators:
        // Distribute Transaction fees and subsidy payments to all outgoing validators
        
        if (Vector::is_empty<address>(&outgoing_compliant_set)) return;

        // don't pay while we are in recovery mode, since that creates a frontrunning opportunity
        if (subsidy_units > 0 && !RecoveryMode::is_recovery()) {
            Subsidy::process_subsidy(vm, subsidy_units, &outgoing_compliant_set);
        };

        Subsidy::process_fees(vm, &outgoing_compliant_set);
    }

    fun propose_new_set(vm: &signer, height_start: u64, height_now: u64): vector<address> {
        print(&99999999999999);

        // Propose upcoming validator set:
        // Get validators we know to be in consensus correctly: Case1 and Case2
        // Only expand the amount of seats so that the new set has a max of 25% unproven nodes. I.e. nodes that were not in the previous epoch and we have stats on.
        
        // in emergency admin roles set the validator set
        // there may be a recovery set to be used.
        // if there is no rescue mission validators, just do usual procedure.
        
        if (RecoveryMode::is_recovery()) {
          let recovery_vals = RecoveryMode::get_debug_vals();
          if (Vector::length(&recovery_vals) > 0) return recovery_vals;
        };

      
        // find good new validators
        // limit the amount of validators so that the new set doesn't have
        // 25% of nodes that we don't know their current performance.

        let previous_set = DiemSystem::get_val_set_addr();
        let proven_nodes = Vector::empty<address>();

        let i = 0;
        while (i < Vector::length<address>(&previous_set)) {
            let addr = *Vector::borrow(&previous_set, i);
            let case = Cases::get_case(vm, addr, height_start, height_now);
            // let mined_last_epoch = TowerState::node_above_thresh(addr);
            // TODO: temporary until jailing is enabled.
            if (
              // TODO: We should include CASE 2
              (case == 1 || case == 2) &&
              // case == 1 &&
              Audit::val_audit_passing(addr)
            ) {
                Vector::push_back(&mut proven_nodes, addr);
            };
            i = i+ 1;
        };

        let len_proven_nodes = Vector::length(&proven_nodes);
        let max_unproven_nodes = len_proven_nodes / 6;
        print(&len_proven_nodes);
        print(&max_unproven_nodes);
        // start from the proven nodes
        let proposed_set = proven_nodes;


        let top_accounts = NodeWeight::top_n_accounts(
            vm, Globals::get_max_validators_per_set()
        );

        // we also need to explicitly filter those which did not do work.
        let jailed_set = DiemSystem::get_jailed_set(vm, height_start, height_now);

        print(&top_accounts);
        print(&jailed_set);

        // let jailed_set = DiemSystem::get_jailed_set(vm, height_start, height_now);
        // find the top unproven nodes and add to the proposed set
        let i = 0;
        while (
          i < Vector::length(&top_accounts) && 
          Vector::length(&proposed_set) < len_proven_nodes + max_unproven_nodes
        ) {
            let addr = *Vector::borrow(&top_accounts, i);
            let mined_last_epoch = TowerState::node_above_thresh(addr);
            
            print(&addr);

            if (
                // ignore those already on list
                !Vector::contains<address>(&proposed_set, &addr) &&
                // jail the current validators which did not perform.
                !Vector::contains<address>(&jailed_set, &addr) &&
                // check the unproven node has done a minimum of work
                mined_last_epoch &&
                Audit::val_audit_passing(addr)
            ) {
                print(&901);
                Vector::push_back(&mut proposed_set, addr);
            };
            i = i+ 1;
        };

        print(&proposed_set);


        // If the cardinality of validator_set in the next epoch is less than 4, 

        // if we are failing to qualify anyone. Pick top 1/2 of validator set by proposals. They are probably online.

        if (Vector::length<address>(&proposed_set) <= 3) proposed_set = Stats::get_sorted_vals_by_props(vm, Vector::length<address>(&proposed_set) / 2);


        // If still failing...in extreme case if we cannot qualify anyone. Don't change the validator set.
        // we keep the same validator set. 
        if (Vector::length<address>(&proposed_set) <= 3) proposed_set = DiemSystem::get_val_set_addr(); // Patch for april incident. Make no changes to validator set.

        // Usually an issue in staging network for QA only.
        // This is very rare and theoretically impossible for network with 
        // at least 6 nodes and 6 rounds. If we reach an epoch boundary with 
        // at least 6 rounds, we would have at least 2/3rd of the validator 
        // set with at least 66% liveliness. 
        proposed_set
    }

    fun reset_counters(vm: &signer, proposed_set: vector<address>, outgoing_compliant: vector<address>, height_now: u64) {

        // Reset Stats
        Stats::reconfig(vm, &proposed_set);

        // Migrate TowerState list from elegible.
        TowerState::reconfig(vm, &outgoing_compliant);
        

        // process community wallets
        DiemAccount::process_community_wallets(vm, DiemConfig::get_current_epoch());
        
        // reset counters
        AutoPay::reconfig_reset_tick(vm);

        Epoch::reset_timer(vm, height_now);

        RecoveryMode::maybe_remove_debug_at_epoch(vm);
        // Reconfig should be the last event.
        // Reconfigure the network
        DiemSystem::bulk_update_validators(vm, proposed_set);


    }

    // NOTE: this was previously in propose_new_set since it used the same loop.
    // copied implementation from Teams proposal.
    fun proof_of_burn(vm: &signer, nominal_subsidy_per: u64, proposed_set: &vector<address>) {
        CoreAddresses::assert_vm(vm);
        DiemAccount::migrate_cumu_deposits(vm); // may need to populate data on a migration.

        Burn::reset_ratios(vm);

        let burn_value = nominal_subsidy_per / 2; // 50% of the current per validator reward

        let vals_to_burn = if (
          !Testnet::is_testnet() &&
          !StagingNet::is_staging_net() &&
          DiemConfig::get_current_epoch() > 185
        ) {
          &ValidatorUniverse::get_eligible_validators(vm)
        } else {
          proposed_set
        };

        // print(vals_to_burn);
        let i = 0;
        while (i < Vector::length<address>(vals_to_burn)) {
          let addr = *Vector::borrow(vals_to_burn, i);
          // print(&addr);

          Burn::epoch_start_burn(vm, addr, burn_value);
          i = i + 1;
        };
    }

}
}