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
      let isSent = set.find(x => x.account_address == each.address)
      return {
        note: each.note,
        address: each.address,
        is_sent: isSent == null ? null : false,
        is_received: true
      }
    })
    validator.vouch.sent.forEach(each => {
      let sent = vouches.find(received => received.address == each.address) 
      if (sent) {
        sent.is_sent = true;
      } else {
        vouches.push({
          note: each.note,
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
          <th>note</th>
          <th>validator</th>
          <th>received</th>
          <th>sent</th>
        </tr>
      </thead>
      <tbody>
        {#each vouches as vouch}
          <tr>
            <td>{vouch.note}</td>
            <td>{vouch.address}</td>
            <td>
              {#if vouch.is_received}
                <span class="uk-text-success" uk-icon="icon: check"></span>
              {/if}
            </td>
            <td>
              {#if vouch.is_sent == null}
                ???
              {:else if vouch.is_sent}
                <span class="uk-text-success" uk-icon="icon: check"></span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
{/if}
      