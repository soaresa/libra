address 0x123 {
module BondingCurve {
  use 0x1::Signer;
  use 0x1::FixedPoint32;

  resource struct CurveState {
    is_deprecated: bool,
    reserve: FixedPoint32::FixedPoint32,
    supply: FixedPoint32::FixedPoint32,
    kappa: FixedPoint32::FixedPoint32
  }

  resource struct Token { 
    value: FixedPoint32::FixedPoint32
  }

  fun sunset() {
    // if true state.is_deprecated == true
    // allow holders to redeem at the spot price at sunset.
    // cannot receive new deposits
    //TBD
  }

  ///////// Initialization /////////
  public fun initialize_curve(
    sponsor: &signer,
    reserve: FixedPoint32::FixedPoint32,
    spot_price: FixedPoint32::FixedPoint32,
    kappa: FixedPoint32::FixedPoint32
  ) {
    // TODO: Kappa will be overriden with `2` until math natives.
    kappa = FixedPoint32::create_from_raw_value(2);

    assert(reserve > FixedPoint32::create_from_raw_value(0), 7357001);

    let supply = calc_init_supply_from_args(kappa, reserve, spot_price);

    let init_state = CurveState {
      is_deprecated: false, // deprecate mode
      reserve: reserve,
      supply: supply,
      kappa: kappa
    };

    // This initializes the contract, and stores the contract state at the address of sender. TDB where the state gets stored.
    move_to<CurveState>(sponsor, init_state);

    // TODO: Check the math works. Check rounding issues
    // TODO: User should not have a benefit from rounding errors.
    // let sponsor_addr = Signer::address_of(sponsor);
    // assert(calc_spot_price_from_state(sponsor_addr) == spot_price, 73570002);


    let first_token = Token { 
      value: supply
    };


    // minting the first coin, sponsor is recipent of initial coin.
    move_to<Token>(sponsor, first_token);
  }

  ///////// Calculations /////////
  fun curve_kappa_two(add_to_reserve: FixedPoint32::FixedPoint32, supply: FixedPoint32::FixedPoint32, reserve: FixedPoint32::FixedPoint32):FixedPoint32::FixedPoint32 {
    let one = FixedPoint32::create_from_raw_value(1);
    supply * sqrt(one+(add_to_reserve/reserve))
  }

  /// TODO: distant future, generalized kappa. Need math natives.
  fun curve_any_kappa() {

  }

  // This is necessary on initializing.
  fun calc_init_supply_from_args(kappa: FixedPoint32::FixedPoint32, reserve_balance: FixedPoint32::FixedPoint32, spot_price: FixedPoint32::FixedPoint32): FixedPoint32::FixedPoint32 {
    kappa * (reserve_balance/spot_price)
  }

  // This is a steady state getter
  public fun calc_spot_price_from_state(sponsor_addr: address): FixedPoint32::FixedPoint32 acquires CurveState {
    let state = borrow_global_mut<CurveState>(sponsor_addr);
    state.kappa * (state.reserve/state.supply)
  }

  // fun calc_fee():FixedPoint32::FixedPoint32 {
  //   1
  // }

  // Merges a token.
  fun deposit_token_to(sender: &signer, new_value: FixedPoint32::FixedPoint32) acquires Token {
    let to_addr = Signer::address_of(sender);
    if (!exists<Token>(to_addr)) {
      move_to<Token>(sender, Token { value: new_value });
    } else {
      let user_token = borrow_global_mut<Token>(to_addr);
      user_token.value = user_token.value + new_value;
    }
  }

  // Splits a coin to be used.
  fun withdraw_token_from(sender: &signer, sub_value: FixedPoint32::FixedPoint32) acquires Token {
    let from_addr = Signer::address_of(sender);
    assert(exists<Token>(from_addr), 73570005);
    let user_token = borrow_global_mut<Token>(from_addr);
    user_token.value = user_token.value - sub_value;
  }

  ///////// API /////////
  public fun bond_to_mint(sender: &signer, sponsor_addr: address, add_to_reserve: FixedPoint32::FixedPoint32):FixedPoint32::FixedPoint32 acquires CurveState, Token{
    assert(exists<CurveState>(sponsor_addr), 73570002);
    let state = borrow_global_mut<CurveState>(sponsor_addr);

    let new_supply = 0;
    if (state.kappa == 2) {
      new_supply = curve_kappa_two(add_to_reserve, state.supply, state.reserve);
    };
    
    let mint = new_supply - state.supply;
    deposit_token_to(sender, mint);
    // new curve state
    state.reserve = state.reserve + add_to_reserve;
    state.supply = new_supply;
    mint
  }

  public fun burn_to_withdraw(sender: &signer, sponsor_addr: address, burn_value: FixedPoint32::FixedPoint32):FixedPoint32::FixedPoint32 acquires CurveState, Token{
    assert(exists<CurveState>(sponsor_addr), 73570002);
    let state = borrow_global_mut<CurveState>(sponsor_addr);

    // Calculate the reserve change.
    let withdraw_value = state.reserve * (1-((1-(burn_value/state.supply))*(1-(burn_value/state.supply))));

    withdraw_token_from(sender, burn_value);
    // new curve state
    state.reserve = state.reserve - withdraw_value;
    state.supply = state.supply - burn_value;
    withdraw_value
  }


  ///////// GETTERS /////////
  public fun get_curve_state(sponsor_address: address): (FixedPoint32::FixedPoint32, FixedPoint32::FixedPoint32) acquires CurveState {
    let state = borrow_global<CurveState>(sponsor_address);
    (state.reserve, state.supply)
  }

  public fun get_user_balance(addr: address): FixedPoint32::FixedPoint32 acquires Token {
    let state = borrow_global<Token>(addr);
    state.value
  }

  ///////// MATH /////////

  //// !!!!! DANGER using while loop for square root for prototype !!!!! ////////
  fun sqrt(y: FixedPoint32::FixedPoint32): FixedPoint32::FixedPoint32 {
    let one = FixedPoint32::create_from_raw_value(1);
    let two = FixedPoint32::create_from_raw_value(2);
    let three = FixedPoint32::create_from_raw_value(3);
    let zero = FixedPoint32::create_from_raw_value(0);

    if (y > three) {
        let z = y;
        let x = y / two + one;
        while (x < z) {
            z = x;
            x = (y / x + x) / two;
        };
        return x
    } else if (y != zero) {
        return one
    };
    zero
  }

  ///////// TEST /////////

  // NOTE:  This "invariant" may not be invariant with rounding issues.
  public fun test_get_curve_invariant(sponsor_addr: address):FixedPoint32::FixedPoint32 acquires CurveState {
    let state = borrow_global_mut<CurveState>(sponsor_addr);
    let two = FixedPoint32::create_from_raw_value(2);
    let zero = FixedPoint32::create_from_raw_value(0);

    // TOOD: when we have native math lib the formula will be:
    // (state.supply, to power of state.kappa) / state.reserve
    if (state.kappa == two ) {
      return (state.supply * state.supply) / state.reserve
    };
    zero
  }



}
}