//! account: alice, 1000000, 0, validator

//////////////////// THIS IS A MODULE ////////////////////
// Normally this belongs in its own file, but for testing simplicity, included here.
module OLFixed {
  use 0x1::Debug::print;
  use 0x1::Errors;


  ///> TODO: This is a basic constant and should be provided somewhere centrally in the framework.
  // (2^64)-1 is max integer
  const MAX_U64: u128 = 18446744073709551615;

  /// The denominator provided was zero
  const EDENOMINATOR: u64 = 0;
  /// The quotient value would be too large to be held in a `u64`
  const EDIVISION: u64 = 1;
  /// The multiplied value would be too large to be held in a `u64`
  const EMULTIPLICATION: u64 = 2;
  /// A division by zero was encountered
  const EDIVISION_BY_ZERO: u64 = 3;
  /// The computed ratio when converting to a `FixedPoint32` would be unrepresentable
  const ERATIO_OUT_OF_RANGE: u64 = 4;


  struct QFormat {
    numerator: u64,
    denominator: u64,
    // TODO: Q format bitstring
    value: u64
  }

  public fun hello(number: u64): u64 {
    print(&number);
    number // returns number
  }

  public fun from_rational(numerator: u64, denominator: u64): QFormat {
    // If the denominator is zero, this will abort.
    // Scale the numerator to have 64 fractional bits and the denominator
    // to have 32 fractional bits, so that the quotient will have 32
    // fractional bits.
    let scaled_numerator = (numerator as u128) << 64;
    let scaled_denominator = (denominator as u128) << 32;
    assert(scaled_denominator != 0, Errors::invalid_argument(1));
    let quotient = scaled_numerator / scaled_denominator;
    assert(quotient != 0 || numerator == 0, Errors::invalid_argument(ERATIO_OUT_OF_RANGE));
    // Return the quotient as a fixed-point number. We first need to check whether the cast
    // can succeed.
    assert(quotient <= MAX_U64, Errors::limit_exceeded(2));

    QFormat {
      numerator: numerator,
      denominator: denominator,
      value: (quotient as u64) 
    }
  }

  public fun get_raw_value(obj: QFormat): u64 {
    obj.value
  }
}
//! new-transaction
//! sender: alice
script {
    use {{default}}::OLFixed; // how to call a module defined in functional test.
    use 0x1::FixedPoint32;
    use 0x1::Debug::print;

    fun main(_: &signer) {
      let hello = OLFixed::hello(10);
      print(&hello);

      let fifty_percent = OLFixed::from_rational(10, 20);
      print(&fifty_percent);
      print(&OLFixed::get_raw_value(fifty_percent));

      

      ////////// FixedPoint32 from Diem //////////// 
      let twenty_five_percent = FixedPoint32::create_from_rational(1,4);
      print(&twenty_five_percent);
      let multiply = FixedPoint32::multiply_u64(100, twenty_five_percent);
      print(&multiply);

    }

}