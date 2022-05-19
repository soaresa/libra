//! account: alice, 4000000, 0, validator
//! account: bob, 1000000, 0, validator
//! account: carol, 1000000, 0, validator
//! account: dave, 1000000, 0, validator
//! account: eve, 1000000, 0, validator
//! account: frank, 1000000, 0, validator

//! new-transaction
//! sender: alice
script {
  use 0x1::DiemAccount;
  use 0x1::ValidatorConfig;
  use 0x1::TestFixtures;
  use 0x1::VDF;
  use 0x1::TowerState;

  fun main(sender: signer) {
    // Scenario: Alice, an existing validator, is sending a transaction for Eve, 
    // with a challenge and proof from eve's block_0
    let challenge = TestFixtures::eve_0_easy_chal();
    let solution = TestFixtures::eve_0_easy_sol();
    // // Parse key and check
    let (eve_addr, _auth_key) = VDF::extract_address_from_challenge(&challenge);
    assert(eve_addr == @0x3DC18D1CF61FAAC6AC70E3A63F062E4B, 401);

    let epochs_since_creation = 10;
    TowerState::test_helper_set_rate_limit(&sender, epochs_since_creation);

    DiemAccount::create_validator_account_with_proof(
        &sender,
        &challenge,
        &solution,
        TestFixtures::easy_difficulty(), // difficulty
        TestFixtures::security(), // security
        b"leet",
        @0xfa72817f1b5aab94658238ddcdc08010,
        x"fa72817f1b5aab94658238ddcdc08010",
        // random consensus_pubkey: vector<u8>,
        x"8108aedfacf5cf1d73c67b6936397ba5fa72817f1b5aab94658238ddcdc08010",
        b"192.168.0.1", // validator_network_addresses: vector<u8>,
        b"192.168.0.1", // fullnode_network_addresses: vector<u8>,
        x"1ee7", // human_name: vector<u8>,
    );
    assert(ValidatorConfig::is_valid(eve_addr), 7357130101031000);

  }
}
//check: EXECUTED

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::EpochBoundary;
    use 0x1::TowerState;
    use 0x1::Mock;

    fun main(vm: signer) {
        let vm = &vm;
        // Tests on initial size of validators
        assert(DiemSystem::validator_set_size() == 6, 7357000180101);
        assert(DiemSystem::is_validator(@{{alice}}) == true, 7357000180102);
        assert(DiemSystem::is_validator(@{{bob}}) == true, 7357000180103);
        assert(
            DiemSystem::is_validator(@0x3DC18D1CF61FAAC6AC70E3A63F062E4B) == false, 
            7357000180104
        );
        assert(TowerState::is_init(@0x3DC18D1CF61FAAC6AC70E3A63F062E4B), 7357000180105);

        Mock::mock_case_1(vm, @{{alice}}, 0, 15);
        Mock::mock_case_1(vm, @{{bob}}, 0, 15);
        Mock::mock_case_1(vm, @{{carol}}, 0, 15);
        Mock::mock_case_1(vm, @{{dave}}, 0, 15);
        Mock::mock_case_1(vm, @{{eve}}, 0, 15);
        Mock::mock_case_1(vm, @{{frank}}, 0, 15);

        EpochBoundary::reconfigure(vm, 15); // reconfigure at height 15
        assert(DiemSystem::validator_set_size() == 6, 7357000180106);
    }
}
// check: EXECUTED

// Epoch 2 began
// The new node is in validatorUniverse but not in validator set

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::ValidatorUniverse;
    use 0x1::Vector;
    fun main(vm: signer) {
        // Tests on initial size of validators
        // New validator is not in this set.
        assert(DiemSystem::validator_set_size() == 6, 7357000180101);
        assert(DiemSystem::is_validator(@{{alice}}) == true, 7357000180102);
        assert(!DiemSystem::is_validator(@0x3DC18D1CF61FAAC6AC70E3A63F062E4B), 7357000180103);
        let len = Vector::length<address>(&ValidatorUniverse::get_eligible_validators(&vm));
        // Is in validator universe
        assert(len == 7, 7357000180104);
      }
}
// check: EXECUTED

// The new node starts mining and submiting proofs in the epoch 2
//
//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::EpochBoundary;
    use 0x1::TowerState;
    use 0x1::Mock;
    use 0x1::Vector;
    use 0x1::ValidatorUniverse;
    use 0x1::Vouch;

    fun main(vm: signer) {
        let vm = &vm;
        // Tests on initial size of validators
        assert(DiemSystem::validator_set_size() == 6, 7357000180201);
        assert(DiemSystem::is_validator(@{{alice}}) == true, 7357000180202);
        assert(DiemSystem::is_validator(@{{bob}}) == true, 7357000180203);
        assert(
            DiemSystem::is_validator(@0x3DC18D1CF61FAAC6AC70E3A63F062E4B) == false, 
            7357000180204
        );
        Mock::mock_case_1(vm, @{{alice}}, 15, 30);
        Mock::mock_case_1(vm, @{{bob}}, 15, 30);
        Mock::mock_case_1(vm, @{{carol}}, 15, 30);
        Mock::mock_case_1(vm, @{{dave}}, 15, 30);
        Mock::mock_case_1(vm, @{{eve}}, 15, 30);
        Mock::mock_case_1(vm, @{{frank}}, 15, 30);

        let list = Vector::singleton<address>(@{{alice}});
        Vector::push_back(&mut list, @{{bob}});
        Vector::push_back(&mut list, @{{carol}});
        Vector::push_back(&mut list, @{{dave}});

        Vouch::vm_migrate(vm, @0x3DC18D1CF61FAAC6AC70E3A63F062E4B, list);
        
        TowerState::test_helper_mock_mining_vm(vm, @0x3DC18D1CF61FAAC6AC70E3A63F062E4B, 20);

        let len = Vector::length<address>(&ValidatorUniverse::get_eligible_validators(vm));
        assert(len == 7 , 7357000180206);

        EpochBoundary::reconfigure(vm, 15); // reconfigure at height 15
    }
}
// check: EXECUTED

// Epoch 3 began
// The new node is in validatorUniverse and also in validator set

//! new-transaction
//! sender: diemroot
script {
    use 0x1::DiemSystem;
    use 0x1::ValidatorUniverse;
    use 0x1::Vector;
    use 0x1::Debug::print;
    fun main(vm: signer) {
        // Tests on initial size of validators
        print(&DiemSystem::validator_set_size());
        assert(DiemSystem::validator_set_size() == 7, 7357000200301);
        assert(DiemSystem::is_validator(@{{alice}}) == true, 7357000200302);
        assert(DiemSystem::is_validator(@0x3DC18D1CF61FAAC6AC70E3A63F062E4B), 7357000200303);
        let len = Vector::length<address>(&ValidatorUniverse::get_eligible_validators(&vm));
        assert(len == 7, 7357000200304);
      }
}
// check: EXECUTED
