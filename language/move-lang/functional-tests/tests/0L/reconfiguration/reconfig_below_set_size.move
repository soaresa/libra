// Testing if validator set remains the same if the size of eligible 
// validators falls below 4

// ALICE is CASE 1
//! account: alice, 1000000, 0, validator
// BOB is CASE 2
//! account: bob, 1000000, 0, validator
// CAROL is CASE 2
//! account: carol, 1000000, 0, validator
// DAVE is CASE 2
//! account: dave, 1000000, 0, validator
// EVE is CASE 3
//! account: eve, 1000000, 0, validator
// FRANK is CASE 2
//! account: frank, 1000000, 0, validator

//! block-prologue
//! proposer: alice
//! block-time: 1
//! NewBlockEvent

//! new-transaction
//! sender: alice
script {
    use 0x1::TowerState;

    fun main(sender: signer) {
        // Miner is the only one that can update their mining stats. 
        // Hence this first transaction.

        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008005001);
    }
}
//check: EXECUTED
//! new-transaction
//! sender: eve
script {
    use 0x1::TowerState;

    fun main(sender: signer) {
        // Miner is the only one that can update their mining stats. 
        // Hence this first transaction.

        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008005002);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: diemroot
script {
    use 0x1::Stats;
    use 0x1::Vector;
    use 0x1::DiemSystem;

    fun main(vm: signer) {
        let voters = Vector::singleton<address>(@{{alice}});
        Vector::push_back<address>(&mut voters, @{{bob}});
        // Vector::push_back<address>(&mut voters, @{{carol}});
        // Vector::push_back<address>(&mut voters, @{{dave}});
        // Skip Eve.
        // Vector::push_back<address>(&mut voters, @{{eve}});
        // Vector::push_back<address>(&mut voters, @{{frank}});

        let i = 1;
        while (i < 15) {
            // Mock the validator doing work for 15 blocks, and stats being updated.
            Stats::process_set_votes(&vm, &voters);
            i = i + 1;
        };

        assert(DiemSystem::validator_set_size() == 6, 7357008005003);
        assert(DiemSystem::is_validator(@{{alice}}) == true, 7357008005004);
    }
}
//check: EXECUTED

//////////////////////////////////////////////
///// Trigger reconfiguration at 61 seconds ////
//! block-prologue
//! proposer: alice
//! block-time: 61000000
//! round: 15

///// TEST RECONFIGURATION IS HAPPENING ////
// check: NewEpochEvent
//////////////////////////////////////////////

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::DiemConfig;
    use 0x1::Debug::print;

    fun main(_account: signer) {
      
        // We are in a new epoch.
        assert(DiemConfig::get_current_epoch() == 2, 7357008005005);
        print(&DiemSystem::validator_set_size());
        // Tests on initial size of validators
        assert(DiemSystem::validator_set_size() == 6, 7357008005006);
    }
}
//check: EXECUTED
