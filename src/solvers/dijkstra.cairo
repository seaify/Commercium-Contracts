%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from cairo_graphs.data_types.data_types import Graph, Edge
from src.lib.utils import Router, Path
from src.lib.dijkstra import Dijkstra
from src.lib.graph import GraphMethods

// This should be a const, but easier like this for testing
@storage_var
func router_aggregator() -> (router_aggregator_address: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_aggregator: felt
) {
    router_aggregator.write(_router_aggregator);
    return ();
}

@view
func get_results{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (
    routers_len: felt,
    routers: Router*,
    path_len: felt,
    path: Path*,
    amounts_len: felt,
    amounts: felt*,
) {
    alloc_locals;

    let (routers: Router*) = alloc();
    let (path: Path*) = alloc();
    let (amounts: felt*) = alloc();

    // Build Edges
    //

    // Generate Graph
    //let (graph: Graph) = GraphMethods.build_directed_graph_from_edges(edges_len: felt, edges: Edge*)

    // Run Dijkstra
    //let (graph: Graph, predecessors: felt*, distances: felt*) = Dijkstra.run(graph, start_identifier);


    return (1, routers, 1, path, 1, amounts);
}
