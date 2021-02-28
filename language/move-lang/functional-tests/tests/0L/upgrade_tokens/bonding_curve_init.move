//! account: sponsor, 1000000, 0, validator
//! account: user, 0, 0

//////////////////// Test Initialization of Curve  ////////////////////

//! new-transaction
//! sender: sponsor
script {
    use 0x123::BondingCurve;
    use 0x1::Debug::print;

    fun main(sponsor: &signer) {
      
      BondingCurve::initialize_curve(
        sponsor,
        100, // starting reserve
        1, // spot price
        1234, // kappa, will overide to 2
      );

      let (r, s) = BondingCurve::get_curve_state({{sponsor}});
      print(&r);
      print(&s);
      assert(r == 100, 73570001);
      assert(s == 200, 73570002);

    }
}
// check: EXECUTED


//////////////////// Test Mint ////////////////////

//! new-transaction
//! sender: user
script {
    use 0x123::BondingCurve;
    use 0x1::Debug::print;

    fun main(sender: &signer) {
      let value = BondingCurve::bond_to_mint(sender, {{sponsor}}, 100000);
      print(&value);
      let (r, s) = BondingCurve::get_curve_state({{sponsor}});
      let user_balance = BondingCurve::get_user_balance({{user}});
      print(&user_balance);
      print(&r);
      print(&s);

      assert(user_balance == 6000, 73570004);
      assert(r == 100100, 73570003);
      assert(s == 6200, 73570004);

    }
}
// check: EXECUTED