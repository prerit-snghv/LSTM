<!-- hdl-kgraph:start -->
<!-- Managed by `hdl-kgraph setup`; edits between these markers are overwritten. -->

## Querying the hdl-kgraph design graph

This repository has a knowledge graph of its HDL design (SystemVerilog / Verilog
/ VHDL) built by [hdl-kgraph](https://github.com/chuanseng-ng/hdl-kgraph). For
structural questions about the design — module hierarchy, where a unit is
instantiated, what drives a signal, clock domains, the impact of a change —
**query the graph instead of grepping the raw RTL**: it resolves cross-file
references and scores each edge by confidence (1.0 resolved, 0.8 unique
cross-file match, 0.6 ambiguous, 0.4 naming heuristic). VHDL names match
case-insensitively. The graph is read-only; rebuild it with `hdl-kgraph build`
or `hdl-kgraph update`.

**Via MCP** (configured for this assistant) — use the tools `find_module`,
`get_hierarchy`, `who_instantiates`, `port_map`, `impact_of_change`,
`find_signal_drivers`, `clock_domains`, `uvm_topology`, `search_nodes`. Start
with `get_hierarchy` or `find_module` to orient.

**Without MCP** (from a shell, or where MCP is not set up) — the same tools are
CLI commands that print the same JSON, for example:

```sh
hdl-kgraph tools find-module fifo
hdl-kgraph tools hierarchy                # tops; add a name for its tree
hdl-kgraph tools impact adder
hdl-kgraph tools find-signal-drivers stage --module df_top
```
<!-- hdl-kgraph:end -->
