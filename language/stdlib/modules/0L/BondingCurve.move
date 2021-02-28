address 0x123 {
module BondingCurve {
  // use 0x1::FixedPoint32;
  // use 0x1::Debug::print;

  resource struct CurveState {
    is_deprecated: bool,
    reserve: u64,
    supply: u64,
    kappa: u64
  }

  resource struct UpgradeToken { 
    value: u64
  }

  fun sunset() {
    // if true state.is_deprecated == true
    // allow holders to redeem at the spot price at sunset.
    // cannot receive new deposits
    //TBD
  }

  public fun initialize_curve(
    sponsor: &signer,
    reserve: u64,
    spot_price: u64,
    kappa: u64
  ) {
    // TODO: Kappa will be overriden with `2` until better bignum arithmetic
    kappa = 2;

    assert(reserve > 0, 7357001);

    let supply = calc_supply_from_price(kappa, reserve, spot_price);

    let init_state = CurveState {
      is_deprecated: false, // deprecate mode
      reserve: reserve,
      supply: supply,
      kappa: kappa
    };


    // This initializes the contract, and stores the contract state at the address of sender. TDB where the state gets stored.
    move_to<CurveState>(sponsor, init_state);


    let token_x = UpgradeToken { 
      value: supply
    };

    // minting the first coin, sponsor is recipent of initial coin.
    move_to<UpgradeToken>(sponsor, token_x);

  }

  /////// GETTERS ///////
  public fun get_curve_state(sponsor_address: address): (u64, u64) acquires CurveState {
    let state = borrow_global<CurveState>(sponsor_address);
    (state.reserve, state.supply)
  }

  fun calc_supply_from_price(kappa: u64, reserve_balance: u64, spot_price: u64): u64 {
    kappa * (reserve_balance/spot_price)
  }

  fun curve_kappa_two(add_to_reserve: u64, supply: u64, reserve: u64):u64 {
    supply * sqrt(1+(add_to_reserve/reserve))
  }



  /// TODO: distant future, generalized kappa
  fun curve_any_kappa() {

  }

  //// !!!!! DANGER using while loop for square root for prototype !!!!! ////////
  fun sqrt(y: u64): u64 {

    if (y > 3) {
        let z = y;
        let x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        };
        return x
    } else if (y != 0) {
        return 1
    };
    0
  }

  /////// APIs ///////
  public fun bond_to_mint(sponsor_addr: address, add_to_reserve: u64):u64 acquires CurveState {
    assert(exists<CurveState>(sponsor_addr), 73570002);
    let state = borrow_global_mut<CurveState>(sponsor_addr);

    let new_supply = 0;
    if (state.kappa == 2) {
      new_supply = curve_kappa_two(add_to_reserve, state.supply, state.reserve);
    };
    
    let mint = new_supply - state.supply;

    // new curve state
    state.reserve = state.reserve + add_to_reserve;
    state.supply = new_supply;
    mint
  }

  public fun burn_to_withdraw(_upgrade_token: u64):u64 {
    1
  }

  public fun calc_fee():u64 {
    1
  }

}
}