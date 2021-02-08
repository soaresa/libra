//! account: alice, 1000000, 0, validator
//! account: bob, 1000000, 0, validator

// The data will be initialized and operated all through alice's account

//! new-transaction
//! sender: alice
script {
    use 0x1::LibraAccount;
    use 0x1::GAS::GAS;
    use 0x1::Debug::print;
    use 0x1::Signer::address_of;
    fun main(sender: &signer){
      let account = address_of(sender);

      let bal = LibraAccount::balance<GAS>(account);
      print(&bal);

      LibraAccount::new_autopay_escrow<GAS>(
        sender,
        {{bob}},
        10,
      );

      let new_bal = LibraAccount::balance<GAS>(account);
      assert(bal > new_bal, 7357001);
      print(&new_bal);
      let escrowed = LibraAccount::get_escrow( sender, {{bob}});
      print(&escrowed);

    }
}
// check: EXECUTED