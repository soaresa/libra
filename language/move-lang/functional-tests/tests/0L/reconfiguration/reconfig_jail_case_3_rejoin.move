// Testing if EVE a CASE 3 Validator gets dropped.

// ALICE is CASE 1
//! account: alice, 1000000, 0, validator
// BOB is CASE 1
//! account: bob, 1000000, 0, validator
// CAROL is CASE 1
//! account: carol, 1000000, 0, validator
// DAVE is CASE 1
//! account: dave, 1000000, 0, validator
// EVE is CASE 3
//! account: eve, 1000000, 0, validator
// FRANK is CASE 1
//! account: frank, 1000000, 0, validator

//! block-prologue
//! proposer: alice
//! block-time: 1
//! NewBlockEvent

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemAccount;
    use 0x1::GAS::GAS;
    use 0x1::ValidatorConfig;

    fun main(sender: signer) {
        // Transfer enough coins to operators
        let oper_bob = ValidatorConfig::get_operator(@{{bob}});
        let oper_eve = ValidatorConfig::get_operator(@{{eve}});
        let oper_dave = ValidatorConfig::get_operator(@{{dave}});
        let oper_alice = ValidatorConfig::get_operator(@{{alice}});
        let oper_carol = ValidatorConfig::get_operator(@{{carol}});
        let oper_frank = ValidatorConfig::get_operator(@{{frank}});
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{bob}}, oper_bob, 50009, x"", x"", &sender);
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{eve}}, oper_eve, 50009, x"", x"", &sender);
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{dave}}, oper_dave, 50009, x"", x"", &sender);
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{alice}}, oper_alice, 50009, x"", x"", &sender);
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{carol}}, oper_carol, 50009, x"", x"", &sender);
        DiemAccount::vm_make_payment_no_limit<GAS>(@{{frank}}, oper_frank, 50009, x"", x"", &sender);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: alice
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::get_count_in_epoch(@{{alice}}) == 5, 7357180101011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: bob
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357300101011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: carol
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357300101011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: dave
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357300101011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: eve
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::get_count_in_epoch(@{{eve}}) == 5, 7357180102011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: frank
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357180102011000);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: diemroot
script {
    // use 0x1::TowerState;
    use 0x1::Stats;
    use 0x1::Vector;
    // use 0x1::EpochBoundary;
    use 0x1::DiemSystem;

    fun main(vm: signer) {
        // todo: change name to Mock epochs
        // TowerState::test_helper_set_epochs(&sender, 5);
        let voters = Vector::singleton<address>(@{{alice}});
        Vector::push_back<address>(&mut voters, @{{bob}});
        Vector::push_back<address>(&mut voters, @{{carol}});
        Vector::push_back<address>(&mut voters, @{{dave}});
        // Skip Eve.
        // Vector::push_back<address>(&mut voters, @{{eve}});
        Vector::push_back<address>(&mut voters, @{{frank}});

        let i = 1;
        while (i < 15) {
            // Mock the validator doing work for 15 blocks, and stats being updated.
            Stats::process_set_votes(&vm, &voters);
            i = i + 1;
        };

        assert(DiemSystem::validator_set_size() == 6, 7357008008007);
        assert(DiemSystem::is_validator(@{{alice}}), 7357008008008);
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
    fun main(_account: signer) {
        // We are in a new epoch.
        assert(DiemConfig::get_current_epoch() == 2, 7357008008009);
        // Tests on initial size of validators 
        assert(DiemSystem::validator_set_size() == 5, 7357008008010);
        assert(DiemSystem::is_validator(@{{eve}}) == false, 7357008008011);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: diemroot
script {
    // use 0x1::EpochBoundary;
    // use 0x1::Cases;
    use 0x1::Vector;
    use 0x1::Stats;
    
    fun main(vm: signer) {
        let vm = &vm;
        // start a new epoch.
        // Everyone validates correctly
        // EVE cannot sign, since she is not in the validator set
        let voters = Vector::singleton<address>(@{{alice}});
        Vector::push_back<address>(&mut voters, @{{bob}});
        Vector::push_back<address>(&mut voters, @{{carol}});
        Vector::push_back<address>(&mut voters, @{{dave}});
        // Vector::push_back<address>(&mut voters, @{{eve}});
        Vector::push_back<address>(&mut voters, @{{frank}});

        let i = 1;
        while (i < 15) {
            // Mock the validator doing work for 15 blocks, and stats being updated.
            Stats::process_set_votes(vm, &voters);
            i = i + 1;
        };

        // // EVE did not SIGN, but did MINE, is a case 3 and will fall out of set.
        // assert(Cases::get_case(vm, @{{eve}}, 0, 15) == 3, 7357008008012);
        // // EpochBoundary::reconfigure(vm, 30);
    }
}
//check: EXECUTED


//! new-transaction
//! sender: alice
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008013);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: bob
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008014);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: carol
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008015);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: dave
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update their mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008016);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: eve
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008017);
    }
}
//check: EXECUTED

//! new-transaction
//! sender: frank
script {
    use 0x1::TowerState;
    use 0x1::AutoPay;

    fun main(sender: signer) {
        AutoPay::enable_autopay(&sender);

        // Miner is the only one that can update her mining stats. Hence this first transaction.
        TowerState::test_helper_mock_mining(&sender, 5);
        assert(TowerState::test_helper_get_count(&sender) == 5, 7357008008018);
    }
}
//check: EXECUTED

///////////////////////////////////////////////
///// Trigger reconfiguration at 4 seconds ////
//! block-prologue
//! proposer: alice
//! block-time: 122000000
//! round: 30

///// TEST RECONFIGURATION IS HAPPENING ////
// check: NewEpochEvent
//////////////////////////////////////////////

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::DiemConfig;
    fun main(_account: signer) {
        assert(DiemConfig::get_current_epoch() == 3, 7357008008019);
        assert(DiemSystem::validator_set_size() == 6, 7357008008020);
        assert(DiemSystem::is_validator(@{{eve}}), 7357008008021);
    }
}
//check: EXECUTED



//! new-transaction
//! sender: eve
script {
    use 0x1::TowerState;

    fun main(sender: signer) {
        // Mock some mining so Eve can send rejoin tx
        TowerState::test_helper_mock_mining(&sender, 100);
    }
}

// EVE SENDS JOIN TX

//! new-transaction
//! sender: eve
stdlib_script::ValidatorScripts::join
// check: "Keep(EXECUTED)"


///////////////////////////////////////////////
///// Trigger reconfiguration at 4 seconds ////
//! block-prologue
//! proposer: alice
//! block-time: 183000000
//! round: 45

///// TEST RECONFIGURATION IS HAPPENING ////
// check: NewEpochEvent
//////////////////////////////////////////////

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::DiemConfig;
    fun main(_account: signer) {
        assert(DiemConfig::get_current_epoch() == 4, 7357008008022);

        // Finally eve is a validator again
        assert(DiemSystem::is_validator(@{{eve}}), 7357008008023);
    }
}
//check: EXECUTED