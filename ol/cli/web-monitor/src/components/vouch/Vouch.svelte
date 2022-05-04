<script lang="ts">
import { afterUpdate } from 'svelte';
import NetworkGraph from './NetworkGraph.svelte';
export let data;

  let graph;  
  afterUpdate(() => {
    if (!data.chain_view || graph) {
      return;
    }
		// create nodes and links
    let nodes = [];
    let links = [];
    let active = [];
    // build nodes
    data.chain_view.validator_view.forEach(val => {
      nodes.push({
        id: val.account_address.toLowerCase(),
        group: 1
      })
      active.push(val.account_address.toLowerCase())
    })

    //build links
    data.chain_view.validator_view.forEach(val => {
      val.vouch.received.forEach(vouch => {
        if (active.indexOf(vouch.address.toLowerCase())) {
          links.push({
            source: val.account_address.toLowerCase(), 
            target: vouch.address.toLowerCase(), 
            value: 1
          })
        }
      })
    })
    graph = {nodes: nodes, links: links};
	});
  
  
  // create links
  // data.vouch.vals.forEach()

  /*
  let data = {
    "nodes": [
      {"id": "Myriel", "group": 2},
      {"id": "Napoleon", "group": 2},
	    {"id": "Mlle.Baptistine", "group": 2},
      {"id": "Mme.Magloire", "group": 2}
    ],
    "links": [
      {"source": "Myriel", "target": "Napoleon", "value": 1},
      {"source": "Napoleon", "target": "Myriel", "value": 1},
      {"source": "Napoleon", "target": "Mme.Magloire", "value": 2},
      {"source": "Mme.Magloire", "target": "Mlle.Baptistine", "value": 3}
    ]
  }
  */

</script>

<style>
	.chart {
		width: 1024px;
		height: 840px;
		margin: 0 auto;
	}
</style>

<div>
  <h2 class="uk-text-center uk-text-uppercase uk-text-muted uk-text-light uk-margin-medium-bottom">
    Vouch
  </h2>
  <div class="chart">
    {#if graph}
      <NetworkGraph graph={graph}/>
    {/if}
  </div>
</div>