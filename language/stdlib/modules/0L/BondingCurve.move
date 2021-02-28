address 0x123 {
module BondingCurve {
  use 0x1::FixedPoint32;
  use 0x1::Debug::print;

  resource struct CurveState { 
    reserve: u64,
    supply: u64,
    kappa: u64
  }

  resource struct UpgradeToken { 
    value: u64
  }

  public fun initialize_my_curve(
    sponsor: &signer,
    recipient_of_initial: &signer,
    reserve: u64,
    supply: u64,
    kappa: u64
  ) {

    assert(reserve > 0, 7357001);

    let init_state = CurveState {
      reserve: reserve,
      supply: supply,
      kappa: kappa
    };


    // This initializes the contract, and stores the contract state at the address of sender. TDB where the state gets stored.
    move_to<CurveState>(sponsor, init_state);


    let token_x = UpgradeToken { 
      value: supply
    };

    // minting the first coin
    move_to<UpgradeToken>(recipient_of_initial, token_x);

  }

  // demo
  public fun not_three(): bool {
    let f2 = FixedPoint32::create_from_rational(1, 3); // 0.333...
    print(&f2);

    let not_three = FixedPoint32::multiply_u64(9, f2); // 9 * 0.333...
    // multiply_u64 does NOT round -- it truncates -- so values that
    // are not perfectly representable in binary may be off by one.
    print(&not_three);
    not_three == 2
  }

  fun the_curve() {

  }

  /////// APIs ///////
  public fun bond_to_mint(_gas_coin: u64):u64 {
    1
  }

  public fun burn_to_withdraw(_upgrade_token: u64):u64 {
    1
  }

}
}