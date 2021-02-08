//! account: alice, 1000000, 0, validator
//! account: bob, 1000000, 0, validator

// The data will be initialized and operated all through alice's account

//! new-transaction
//! sender: alice
script {
    use 0x0::LibraAccount;
    use 0x0::GAS::T;
    fun main(sender: &signer){
      let coin =LibraAccount::withdraw_from<T>(sender, 10);
      LibraAccount::new_autopay_escrow<T>(
        sender,
        {{bob}},
        coin,
      );

    }
}
// check: EXECUTED