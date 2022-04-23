address 0x1 {
module BurnScript {

    use 0x1::Burn;
    public(script) fun set_burn_pref(sender: signer, to_community: bool) {
        Burn::set_send_community(&sender, to_community);
    }
  }
}