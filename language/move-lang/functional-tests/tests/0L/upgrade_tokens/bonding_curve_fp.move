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
        1234, // kappa, will override to 2
      );

      let (r, s) = BondingCurve::get_curve_state({{sponsor}});
      print(&0x111111111111);
      print(&r);

      print(&0x222222222222);
      print(&s);

      print(&0x333333333333);
      let inv = BondingCurve::test_get_curve_invariant({{sponsor}});
      print(&inv);

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
      
      let (r, s) = BondingCurve::get_curve_state({{sponsor}});
      let user_balance = BondingCurve::get_user_balance({{user}});

      print(&0x111111111111);
      print(&r);
      print(&0x222222222222);
      print(&s);
      print(&0x333333333333);
      let inv = BondingCurve::test_get_curve_invariant({{sponsor}});
      print(&inv);
      print(&0x444444444444);
      print(&user_balance);
      print(&0x555555555555);
      print(&value);

      assert(user_balance == 6000, 73570003);
      assert(r == 100100, 73570004);
      assert(s == 6200, 73570005);



    }
}
// check: EXECUTED


//! new-transaction
//! sender: user
script {
    use 0x123::BondingCurve;
    use 0x1::Debug::print;

    fun main(sender: &signer) {
      let value = BondingCurve::burn_to_withdraw(sender, {{sponsor}}, 6000);

      let (r, s) = BondingCurve::get_curve_state({{sponsor}});
      let user_balance = BondingCurve::get_user_balance({{user}});

      print(&0x111111111111);
      print(&r);

      print(&0x222222222222);
      print(&s);

      print(&0x333333333333);
      let inv = BondingCurve::test_get_curve_invariant({{sponsor}});
      print(&inv);

      print(&0x444444444444);
      print(&user_balance);

      print(&0x555555555555);
      print(&value);

      print(&0x666666666666);
      let sponsor_balance = BondingCurve::get_user_balance({{sponsor}});
      print(&sponsor_balance);


      // assert(user_balance == 0, 73570001);
      // assert(r == 0, 73570002);
      // assert(s == 200, 73570003);

    }
}
// check: EXECUTED