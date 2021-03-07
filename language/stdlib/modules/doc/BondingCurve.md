
<a name="0x123_BondingCurve"></a>

# Module `0x123::BondingCurve`



-  [Resource `CurveState`](#0x123_BondingCurve_CurveState)
-  [Resource `Token`](#0x123_BondingCurve_Token)
-  [Function `sunset`](#0x123_BondingCurve_sunset)
-  [Function `initialize_curve`](#0x123_BondingCurve_initialize_curve)
-  [Function `curve_kappa_two`](#0x123_BondingCurve_curve_kappa_two)
-  [Function `curve_any_kappa`](#0x123_BondingCurve_curve_any_kappa)
-  [Function `calc_supply_from_price`](#0x123_BondingCurve_calc_supply_from_price)
-  [Function `calc_fee`](#0x123_BondingCurve_calc_fee)
-  [Function `deposit_token_to`](#0x123_BondingCurve_deposit_token_to)
-  [Function `withdraw_token_from`](#0x123_BondingCurve_withdraw_token_from)
-  [Function `bond_to_mint`](#0x123_BondingCurve_bond_to_mint)
-  [Function `burn_to_withdraw`](#0x123_BondingCurve_burn_to_withdraw)
-  [Function `get_curve_state`](#0x123_BondingCurve_get_curve_state)
-  [Function `get_user_balance`](#0x123_BondingCurve_get_user_balance)
-  [Function `sqrt`](#0x123_BondingCurve_sqrt)


<pre><code><b>use</b> <a href="Signer.md#0x1_Signer">0x1::Signer</a>;
</code></pre>



<a name="0x123_BondingCurve_CurveState"></a>

## Resource `CurveState`



<pre><code><b>resource</b> <b>struct</b> <a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>is_deprecated: bool</code>
</dt>
<dd>

</dd>
<dt>
<code>reserve: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>supply: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>kappa: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x123_BondingCurve_Token"></a>

## Resource `Token`



<pre><code><b>resource</b> <b>struct</b> <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>value: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x123_BondingCurve_sunset"></a>

## Function `sunset`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_sunset">sunset</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_sunset">sunset</a>() {
  // <b>if</b> <b>true</b> state.is_deprecated == <b>true</b>
  // allow holders <b>to</b> redeem at the spot price at sunset.
  // cannot receive new deposits
  //TBD
}
</code></pre>



</details>

<a name="0x123_BondingCurve_initialize_curve"></a>

## Function `initialize_curve`



<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_initialize_curve">initialize_curve</a>(sponsor: &signer, reserve: u64, spot_price: u64, kappa: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_initialize_curve">initialize_curve</a>(
  sponsor: &signer,
  reserve: u64,
  spot_price: u64,
  kappa: u64
) {
  // TODO: Kappa will be overriden <b>with</b> `2` until math natives.
  kappa = 2;

  <b>assert</b>(reserve &gt; 0, 7357001);

  <b>let</b> supply = <a href="BondingCurve.md#0x123_BondingCurve_calc_supply_from_price">calc_supply_from_price</a>(kappa, reserve, spot_price);

  <b>let</b> init_state = <a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a> {
    is_deprecated: <b>false</b>, // deprecate mode
    reserve: reserve,
    supply: supply,
    kappa: kappa
  };


  // This initializes the contract, and stores the contract state at the address of sender. TDB <b>where</b> the state gets stored.
  move_to&lt;<a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>&gt;(sponsor, init_state);


  <b>let</b> first_token = <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a> {
    value: supply
  };

  // minting the first coin, sponsor is recipent of initial coin.
  move_to&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(sponsor, first_token);
}
</code></pre>



</details>

<a name="0x123_BondingCurve_curve_kappa_two"></a>

## Function `curve_kappa_two`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_curve_kappa_two">curve_kappa_two</a>(add_to_reserve: u64, supply: u64, reserve: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_curve_kappa_two">curve_kappa_two</a>(add_to_reserve: u64, supply: u64, reserve: u64):u64 {
  supply * <a href="BondingCurve.md#0x123_BondingCurve_sqrt">sqrt</a>(1+(add_to_reserve/reserve))
}
</code></pre>



</details>

<a name="0x123_BondingCurve_curve_any_kappa"></a>

## Function `curve_any_kappa`

TODO: distant future, generalized kappa. Need math natives.


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_curve_any_kappa">curve_any_kappa</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_curve_any_kappa">curve_any_kappa</a>() {

}
</code></pre>



</details>

<a name="0x123_BondingCurve_calc_supply_from_price"></a>

## Function `calc_supply_from_price`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_calc_supply_from_price">calc_supply_from_price</a>(kappa: u64, reserve_balance: u64, spot_price: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_calc_supply_from_price">calc_supply_from_price</a>(kappa: u64, reserve_balance: u64, spot_price: u64): u64 {
  kappa * (reserve_balance/spot_price)
}
</code></pre>



</details>

<a name="0x123_BondingCurve_calc_fee"></a>

## Function `calc_fee`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_calc_fee">calc_fee</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_calc_fee">calc_fee</a>():u64 {
  1
}
</code></pre>



</details>

<a name="0x123_BondingCurve_deposit_token_to"></a>

## Function `deposit_token_to`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_deposit_token_to">deposit_token_to</a>(sender: &signer, new_value: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_deposit_token_to">deposit_token_to</a>(sender: &signer, new_value: u64) <b>acquires</b> <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a> {
  <b>let</b> to_addr = <a href="Signer.md#0x1_Signer_address_of">Signer::address_of</a>(sender);
  <b>if</b> (!<b>exists</b>&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(to_addr)) {
    move_to&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(sender, <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a> { value: new_value });
  } <b>else</b> {
    <b>let</b> user_token = borrow_global_mut&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(to_addr);
    user_token.value = user_token.value + new_value;
  }
}
</code></pre>



</details>

<a name="0x123_BondingCurve_withdraw_token_from"></a>

## Function `withdraw_token_from`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_withdraw_token_from">withdraw_token_from</a>(sender: &signer, sub_value: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_withdraw_token_from">withdraw_token_from</a>(sender: &signer, sub_value: u64) <b>acquires</b> <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a> {
  <b>let</b> from_addr = <a href="Signer.md#0x1_Signer_address_of">Signer::address_of</a>(sender);
  <b>assert</b>(<b>exists</b>&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(from_addr), 73570005);
  <b>let</b> user_token = borrow_global_mut&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(from_addr);
  user_token.value = user_token.value - sub_value;
}
</code></pre>



</details>

<a name="0x123_BondingCurve_bond_to_mint"></a>

## Function `bond_to_mint`



<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_bond_to_mint">bond_to_mint</a>(sender: &signer, sponsor_addr: address, add_to_reserve: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_bond_to_mint">bond_to_mint</a>(sender: &signer, sponsor_addr: address, add_to_reserve: u64):u64 <b>acquires</b> <a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>, <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>{
  <b>assert</b>(<b>exists</b>&lt;<a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>&gt;(sponsor_addr), 73570002);
  <b>let</b> state = borrow_global_mut&lt;<a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>&gt;(sponsor_addr);

  <b>let</b> new_supply = 0;
  <b>if</b> (state.kappa == 2) {
    new_supply = <a href="BondingCurve.md#0x123_BondingCurve_curve_kappa_two">curve_kappa_two</a>(add_to_reserve, state.supply, state.reserve);
  };

  <b>let</b> mint = new_supply - state.supply;
  <a href="BondingCurve.md#0x123_BondingCurve_deposit_token_to">deposit_token_to</a>(sender, mint);
  // new curve state
  state.reserve = state.reserve + add_to_reserve;
  state.supply = new_supply;
  mint
}
</code></pre>



</details>

<a name="0x123_BondingCurve_burn_to_withdraw"></a>

## Function `burn_to_withdraw`



<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_burn_to_withdraw">burn_to_withdraw</a>(_upgrade_token: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_burn_to_withdraw">burn_to_withdraw</a>(_upgrade_token: u64):u64 {
  1
}
</code></pre>



</details>

<a name="0x123_BondingCurve_get_curve_state"></a>

## Function `get_curve_state`



<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_get_curve_state">get_curve_state</a>(sponsor_address: address): (u64, u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_get_curve_state">get_curve_state</a>(sponsor_address: address): (u64, u64) <b>acquires</b> <a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a> {
  <b>let</b> state = borrow_global&lt;<a href="BondingCurve.md#0x123_BondingCurve_CurveState">CurveState</a>&gt;(sponsor_address);
  (state.reserve, state.supply)
}
</code></pre>



</details>

<a name="0x123_BondingCurve_get_user_balance"></a>

## Function `get_user_balance`



<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_get_user_balance">get_user_balance</a>(addr: address): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_get_user_balance">get_user_balance</a>(addr: address): u64 <b>acquires</b> <a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a> {
  <b>let</b> state = borrow_global&lt;<a href="BondingCurve.md#0x123_BondingCurve_Token">Token</a>&gt;(addr);
  state.value
}
</code></pre>



</details>

<a name="0x123_BondingCurve_sqrt"></a>

## Function `sqrt`



<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_sqrt">sqrt</a>(y: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="BondingCurve.md#0x123_BondingCurve_sqrt">sqrt</a>(y: u64): u64 {
  <b>if</b> (y &gt; 3) {
      <b>let</b> z = y;
      <b>let</b> x = y / 2 + 1;
      <b>while</b> (x &lt; z) {
          z = x;
          x = (y / x + x) / 2;
      };
      <b>return</b> x
  } <b>else</b> <b>if</b> (y != 0) {
      <b>return</b> 1
  };
  0
}
</code></pre>



</details>


[//]: # ("File containing references which can be used from documentation")
[ACCESS_CONTROL]: https://github.com/libra/lip/blob/master/lips/lip-2.md
[ROLE]: https://github.com/libra/lip/blob/master/lips/lip-2.md#roles
[PERMISSION]: https://github.com/libra/lip/blob/master/lips/lip-2.md#permissions
