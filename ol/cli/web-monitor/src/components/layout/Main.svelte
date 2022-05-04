<script>
  import Nav from "./Nav.svelte";
  import Dash from "../monitor/Dash.svelte";
  import Vals from "../validators/Vals.svelte";
  import Upgrade from "../upgrade/Upgrade.svelte";
  import AutoPay from "../autopay/AutoPay.svelte";
  import WatchList from "../watch-list/WatchList.svelte";
  import AuditVals from "../audit/AuditVals.svelte";
  import Vouch from "../vouch/Vouch.svelte";
  import { onDestroy } from 'svelte';
  import { chainInfo } from "../../store.ts";

  let data;
  
  const unsubscribe = chainInfo.subscribe((info_str) => {
    data = JSON.parse(info_str);

    if (!data.chain_view || !data.chain_view.validator_view) {
      return;
    }

    /* map vouch sent */
    let senders = {};
    data.chain_view.validator_view.forEach(receiver => {
      receiver.vouch.received.forEach(sender => {
        let receivers = senders[sender.address] || [];
        receivers.push({
          address: receiver.account_address.toLowerCase(),
          note: receiver.note
        })
        senders[sender.address] = receivers
      })
    });

    /* set vouch sender */
    data.chain_view.validator_view.forEach(val => {
      val.vouch.sent = senders[val.account_address.toLowerCase()] || [];
    });
  });
  
  onDestroy(unsubscribe);
</script>

<main uk-height-viewport="expand: true" class="uk-background-muted uk-overflow-auto">
  <Nav />
  <div class="uk-container uk-margin-top">
    <ul class="uk-switcher uk-margin switcher-container uk-height-large">
      <Dash data={data}/>
      <Vals data={data}/>
      <Vouch data={data}/>
      <AutoPay account={data.account_view}/>
      <WatchList data={data}/>
      <AuditVals data={data}/>      
      <Upgrade data={data}/>
    </ul>
  </div>
</main>
