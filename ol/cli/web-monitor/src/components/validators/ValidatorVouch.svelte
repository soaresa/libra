<script lang="ts">
  import { afterUpdate } from "svelte";

  export let validator;
  export let set; // temporary
  
  let vouches;
  afterUpdate(() => {
    if (!validator || !validator.vouch) {
      return;
    }

    // build vouch table data
    vouches = validator.vouch.received.map(each => {
      let sender = set.find(x => x.account_address == each.address.toUpperCase())
      let isSent = sender == null ? null : false
      return {
        note: each.note,
        has_grafana: sender ? sender.has_grafana : null,
        address: each.address,
        is_sent: isSent,
        is_received: true
      }
    })
    validator.vouch.sent.forEach(each => {
      let receiver = set.find(x => x.account_address == each.address.toUpperCase())
      let sent = vouches.find(received => received.address == each.address) 
      if (sent) {
        sent.is_sent = true;
      } else {
        vouches.push({
          note: each.note,
          has_grafana: receiver ? receiver.has_grafana : null,
          address: each.address,
          is_sent: true,
          is_received: false
        })
      }
    })
  })

</script>

<h3 class="uk-text-muted">Vouch</h3>
{#if vouches}
  {#if vouches.length == 0}
    <p>Empty vouch</p>
  {:else}
    <table class="uk-table">
      <thead>
        <tr>
          <th>#</th>
          <th>note</th>
          <th>validator</th>
          <th class="uk-text-center">received</th>
          <th class="uk-text-center">sent</th>
          <th class="uk-text-center">grafana</th>
        </tr>
      </thead>
      <tbody>
        {#each vouches as vouch, i}
          <tr>
            <td>{i+1}</td>
            <td>{vouch.note}</td>
            <td>{vouch.address}</td>
            <td class="uk-text-center">
              {#if vouch.is_received}
                <span class="uk-text-success" uk-icon="icon: check"></span>
              {/if}
            </td>
            <td class="uk-text-center">
              {#if vouch.is_sent == null}
                ???
              {:else if vouch.is_sent}
                <span class="uk-text-success" uk-icon="icon: check"></span>
              {/if}
            </td>
            <td class="uk-text-center">
              {#if vouch.has_grafana == null}
                ???
              {:else}
                <span 
                  uk-icon="icon: {vouch.has_grafana ? "check" : "close"}"
                  class="{vouch.has_grafana ? "uk-text-success" : "uk-text-danger"}"
                ></span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
{/if}
      