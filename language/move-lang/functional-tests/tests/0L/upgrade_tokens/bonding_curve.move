//! account: alice, 1000000, 0, validator

//! new-transaction
//! sender: alice
script {
    use 0x123::BondingCurve;
    use 0x1::Debug::print;

    fun main(_alice: &signer) {
      let is_three = BondingCurve::not_three();
      print(&is_three);
    }
}
// check: EXECUTED
