<script lang="ts">
  export let data;

  let ports = [];
  let set = [];
  let has_notes = false;
  let has_grafana = false;
  $: if (data.chain_view && data.chain_view.validator_view) {
    set = data.chain_view.validator_view.sort((a, b) => (a.ports_status[6180] > b.ports_status[6180]) ? -1 : 1);;
    has_notes = set.some(e => e.note != "");
    has_grafana = set.some(e => e.has_grafana != null);
    ports = set.length > 0 ? Object.keys(set[0].ports_status) : [];
  }  

</script>

<main>
  <table class="uk-table uk-table-hover uk-text-muted">
    <thead>
      <tr>
        {#if has_notes}
          <th class="uk-text-center">note</th>
        {/if}
        {#if has_grafana}
          <th class="uk-text-center">grafana</th>
        {/if}
        <th class="uk-text-center">account</th>
        <th class="uk-text-left">val ip</th>
        <th class="uk-text-left">vfn ip</th>
        {#each ports as port}
          <th class="uk-text-center">val port {port}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each set as val}
        <tr>
          {#if has_notes}
            <td class="uk-text-center">{val.note}</td>
          {/if}
          {#if has_grafana}
            <td class="uk-text-center">
              <span 
                uk-icon="icon: {val.has_grafana ? "check" : "close"}"
                class="{val.has_grafana ? "uk-text-success" : "uk-text-danger"}"
              ></span>
            </td>
          {/if}
          <td class="uk-visible@s uk-text-center">{val.account_address}</td>
          <td class="uk-hidden@s uk-text-truncate">{val.account_address}</td>
          <td>{val.validator_ip}</td>
          <td>{val.vfn_ip}</td>
          {#each ports as port}
            <td class="uk-text-center">
              <span 
                uk-icon="icon: {val.ports_status[port] ? "check" : "close"}"
                class="{val.ports_status[port] ? "uk-text-success" : "uk-text-danger"}"
              ></span>
            </td> 
          {/each}          
        </tr>
      {/each}
    </tbody>
  </table>
</main>
