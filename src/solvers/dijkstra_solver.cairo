// SPDX-License-Identifier: MIT
// @author FreshPizza

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.lib.graph import GraphConstructor, Source, Edge
from src.lib.utils import Router, Path
from openzeppelin.access.ownable.library import Ownable

// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                             //
//                      DEX aggregation algorithm that makes use of the Dijksta algorithm.                                     //
//                                                                                                                             //
// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


struct Heap{
	value felt,
	nodes felt*,
}

/////////////////////////////
//       Constructor       //
/////////////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt, _router_aggregator: felt
) {
    Ownable.initializer(_owner);
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

    // Generate Vertices
    let (tokens: felt*) = alloc();
    assert tokens[0] = _token_in;
    let (Vertices) = GraphConstructor.construct_vertices(
        _token_in=_token_in, _token_out=_token_out, _tokens=tokens + 1, _liq_counter=0, _counter=2
    );

    // Declare Arrays that make up the Graph
    let (src: Source*) = alloc();
    let (edge: Edge*) = alloc();

    // transform input amount to USD amount (Used for determining edge weights)
    let (router_aggregator_address) = router_aggregator.read();
    //Price is scaled by 1e18
    let (price: Uint256, _) = IRouterAggregator.get_global_price(
        router_aggregator_address, tokens[0]
    );
    let (amount_in_usd: Uint256) = Utils.fmul(price, _amount_in, Uint256(BASE, 0));

    // Build the graph
    GraphConstructor.build_graph(
        _amount_in,
        amount_in_usd,
        Vertices,
        tokens,
        Vertices,
        src,
        _edge_len=0,
        _edge=edge,
        _dst_counter=1,
        _src_counter=0,
        _total_counter=0,
    );

    // Initialize Parameters required for Dijkstra algorithm
    let (distances: felt*) = alloc();
    let (predecessors: felt*) = alloc();
    let (was_visited: felt*) = alloc();
    let (queue: Heap*) = alloc();
    init_arrays(
        _distances_len=Vertices,
        _distances=distances,
        _predecessors=predecessors,
        _was_visited=was_visited,
        _queue=queue,
        _counter=0,
    );

    // Build token arr (determine vertices)

    // Build Edges
    // build_edges(edges)

    // Generate Graph
    // let (graph: Graph) = GraphMethods.build_directed_graph_from_edges(edges_len: felt, edges: Edge*)

    // Run Dijkstra
    // let (graph: Graph, predecessors: felt*, distances: felt*) = Dijkstra.run(graph, start_identifier);

    return (1, routers, 1, path, 1, amounts);
}

// @notice Initialize all relevant Arrays used by the SPF algorithm
// @param _distances - An array of "distance" for each vertex to the origin
// @param _predecessors - An Array that contains the vertices of the shortest path
// @param _is_in_queue - An array of bools that is used to determine whether a vertex is currently in the spf queue
// @param _queue - An array of tokens that makes up the spf queue
// @param _counter - A counter used to track the number of iterations
func init_arrays{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _distances_len: felt,
    _distances: felt*,
    _predecessors: felt*,
    _was_visited: felt*,
    _queue: Heap*,
    _counter: felt,
) -> () {
    if (_counter == _distances_len) {
        return ();
    }

    if (_counter == 0) {
        assert _distances[0] = 0;
        assert _queue[0] = Heap(0,0);  // value = 0, nodes = origin
        assert _predecessors[0] = 0;
        assert _was_visited[0] = 0;
        init_arrays(
            _distances_len,
            _distances + 1,
            _predecessors + 1,
            _was_visited + 1,
            _queue,
            _counter + 1,
        );
        return ();
    } else {
        assert _distances[0] = MAX_FELT;
        assert _predecessors[0] = 0;
        assert _was_visited[0] = 0;
        init_arrays(
            _distances_len,
            _distances + 1,
            _predecessors + 1,
            _is_in_queue + 1,
            _queue,
            _counter + 1,
        );
        return ();
    }
}

// @notice Dijkstra algortihm logic
// @param _distances - An array of "distance" for each vertex to the origin
// @param _is_in_queue - An array of bools that is used to determine whether a vertex is currently in the spf queue
// @param _queue - An array of tokens that makes up the spf queue
// @param _vertices - number of vercies/routers in the graph
// @param _src - array of Edge ranges. Used to map edges to a vertice
// @param _edge - array of graph Edges
// @param _predecessors - array that contains the vertices of the shortest path
func dijkstra{
    syscall_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    _distances_len: felt,
    _distances: felt*,
    _was_visited_len: felt,
    _was_visited: felt*,
    _queue_len: felt,
    _queue: Heap*,
    _vertices: felt,
    _src: Source*,
    _edge: Edge*,
    _predecessors_len: felt,
    _predecessors: felt*,
) -> (final_distances: felt*) {
    alloc_locals;

    // If there is no destination left in the queue we can stop the procedure
    if (_queue_len == 0) {
        return (_predecessors,);
    }

    // Get first entry from queue
    let (new_queue: Heap*) = alloc();
    let (src_nr: felt) = Array.shift(_queue_len - 1, new_queue, _queue_len, _queue, 0, 0);
    tempvar new_queue_len = _queue_len - 1;

    // Get Source from queue Nr
    let current_source: Source* = _src + (src_nr * 2);
    tempvar offset = current_source[0].start;

    // Check if removed item was already visited
    if (_was_visited[src_nr] == 1) {
        //if yes, <continue>
        let (predecessors) = dijkstra(
            _distances_len,
            _distances,
            _was_visited_len,
            _was_visited,
            new_new_queue_len,
            new_new_queue,
            _vertices,
            _src,
            _edge,
            _predecessors_len,
            _predecessors,
        );
        return(predecessors);
    }

    // Stop algorithm if we've reached the destination vertex
    if (src_nr == _vertices - 1) {
        return (_predecessors,);
    }

    // Get Source from queue Nr
    let current_source: Source* = _src + (src_nr * 2);
    tempvar offset = current_source[0].start;

    // Get distance of current vertex
    tempvar current_distance = _distances[src_nr];

    // Determine if there is a shorter distance to its different destinations
    let (
        _,
        new_distances: felt*,
        new_new_queue_len,
        new_new_queue: felt*,
        _,
        new_new_is_in_queue: felt*,
        _,
        new_predecessors: felt*,
    ) = determine_distances(
        _distances_len,
        _distances,
        new_queue_len,
        new_queue,
        _is_in_queue_len,
        new_is_in_queue,
        _vertices,
        _edge + (offset * 4),
        _predecessors_len,
        _predecessors,
        current_source[0].stop,
        src_nr,
        current_distance,
    );

    // Set current vertex as being visited
    // Mark the removed entry as not being in the queue anymore
    let (new_was_visited: felt*) = alloc();
    Array.update(
        _new_arr_len=_was_visited_len,
        _new_arr=new_was_visited,
        _arr_len=_was_visited_len,
        _arr=_was_visited,
        _index=src_nr,
        _new_val=1,
        _counter=0,
    );

    let (predecessors) = dijkstra(
        _distances_len,
        new_distances,
        _was_visited_len,
        new_was_visited,
        new_new_queue_len,
        new_new_queue,
        _vertices,
        _src,
        _edge,
        _predecessors_len,
        new_predecessors,
    );

    return (predecessors,);
}

// @notice For a given vertex determine the distances to its neighbors
// @param _distances - An array of "distance" for each vertex to the origin
// @param _queue - An array of tokens that makes up the spf queue
// @param _is_in_queue - An array of bools that is used to determine whether a vertex is currently in the spf queue
// @param _vertices - number of vercies/routers in the graph
// @param _edge - array of graph Edges
// @param _predecessors - array that contains the vertices of the shortest path
// @param _dst_stop - The lenght of the neighbors/destinations that we iterate through
// @param _src_nr - The index of the vertex in question in the Source arr
// @param _current_distance - The current distance of the vertex in question
// @return routers - Array of routers that are used in the trading path
// @return path - Array of token pairs that are used in the trading path
// @return amounts - Array of token amount that are used in the trading path
func determine_distances{
    syscall_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    _distances_len: felt,
    _distances: felt*,
    _queue_len: felt,
    _queue: felt*,
    _is_in_queue_len: felt,
    _is_in_queue: felt*,
    _vertices: felt,
    _edge: Edge*,
    _predecessors_len: felt,
    _predecessors: felt*,
    _dst_stop: felt,
    _src_nr: felt,
    _current_distance: felt,
) -> (
    _distances_len: felt,
    _distances: felt*,
    _queue_len: felt,
    _queue: felt*,
    _was_visited_len: felt,
    _was_visited: felt*,
    res_predecessors_len: felt,
    res_predecessors: felt*,
) {
    alloc_locals;

    if (_dst_stop == 0) {
        // We end the procedure if all destinations have been evaluated
        return (
            _distances_len,
            _distances,
            _queue_len,
            _queue,
            _is_in_queue_len,
            _is_in_queue,
            _predecessors_len,
            _predecessors,
        );
    }

    let (new_distances: felt*) = alloc();
    local new_queue_len: felt;
    local new_distance: felt;
    let (new_queue: felt*) = alloc();

    local is_dst_end = is_le_felt(_vertices - 1, _edge[0].dst);

    if (is_dst_end == 1) {
        // Moving towards the goal token should always improve the distance
        assert new_distance = _current_distance - EXTRA_BASE + _edge[0].weight;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        assert new_distance = _current_distance + _edge[0].weight;
        tempvar range_check_ptr = range_check_ptr;
    }


    // If nvertex was never visited, add new distance
    if (_was_visited[_edge[0].dst] == 0) {
        // destination vertex weight = origin vertex + edge weight
        Array.update(
            _distances_len, new_distances, _distances_len, _distances, _edge[0].dst, new_distance, 0
        );

        // We safe the destination vertexes best predecessor (which is this current vertex)
        let (new_predecessors: felt*) = alloc();
        Array.update(
            _predecessors_len,
            new_predecessors,
            _predecessors_len,
            _predecessors,
            _edge[0].dst,
            _src_nr,
            0,
        );

        // Add new vertex with better weight to queue
        Array.push(_queue_len + 1, new_queue, _queue_len, _queue, _edge[0].dst);
        assert new_queue_len = _queue_len + 1;

        Array.update(
            _is_in_queue_len,
            new_is_in_queue,
            _is_in_queue_len,
            _is_in_queue,
            _edge[0].dst,
            1,
            0,
        );

        let (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue,
            res_predecessors_len,
            res_predecessors,
        ) = determine_distances(
            _distances_len,
            new_distances,
            new_queue_len,
            new_queue,
            _is_in_queue_len,
            new_is_in_queue,
            _vertices,
            _edge + 4,
            _predecessors_len,
            new_predecessors,
            _dst_stop - 1,
            _src_nr,
            _current_distance,
        );
        return (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue,
            res_predecessors_len,
            res_predecessors,
        );
        
    } else {
        let (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue,
            res_predecessors_len,
            res_predecessors,
        ) = determine_distances(
            _distances_len,
            _distances,
            _queue_len,
            _queue,
            _is_in_queue_len,
            _is_in_queue,
            _vertices,
            _edge + 4,
            _predecessors_len,
            _predecessors,
            _dst_stop - 1,
            _src_nr,
            _current_distance,
        );

        return (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue,
            res_predecessors_len,
            res_predecessors,
        );
    }
}

// //////////////////////
//       Admin        //
// //////////////////////

// @notice Store a token that is considered as liquid and will always be part of the array of vertices
// @dev admin function that can be used to override existing mappings or add a new high liquidity token.
//      The high_liq_tokens mapping is used as an array. So the admin has to ensure that there is no gap
//      in the list of indices.
// @param _index - Token sold / Origin vertex
// @param _high_liq_tokens - Token bought / Destination vertex
@external
func set_high_liq_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index: felt, _high_liq_tokens: felt
) {
    Ownable.assert_only_owner();
    high_liq_tokens.write(_index, _high_liq_tokens);
    return ();
}
