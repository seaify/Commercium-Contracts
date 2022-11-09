// SPDX-License-Identifier: MIT
// / @author FreshPizza
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_eq

from src.lib.array import Array
from src.lib.graph import GraphConstructor, Source, Edge, router_aggregator
from src.lib.utils import Utils, Router, Path
from src.lib.constants import MAX_FELT, BASE
from src.interfaces.i_router_aggregator import IRouterAggregator
from openzeppelin.access.ownable.library import Ownable

const EXTRA_BASE = BASE * 100;  // We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                             //
//                      DEX aggregation algorithm that makes use of the Shortest Path Faster algorithm.                        //
//           See here for alternate implementations: https://www.geeksforgeeks.org/shortest-path-faster-algorithm/             //
//                                                                                                                             //
// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ///////////////////////////
//       Constructor       //
// ///////////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt, _router_aggregator: felt
) {
    GraphConstructor.init(_owner,_router_aggregator);
    return ();
}

// //////////////////////
//       Views        //
// //////////////////////

// @notice Find the optimal trading path using the SPF algorithm
// @param _amount_in - Number of tokens to be sold
// @param _token_in - Address of the token to be sold
// @param _token_out - Address of the token to be bougth
// @return routers - Array of routers that are used in the trading path
// @return path - Array of token pairs that are used in the trading path
// @return amounts - Array of token amount that are used in the trading path
@view
func get_results{
    syscall_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
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

    // Initialize Parameters required for SPF algorithm
    let (distances: felt*) = alloc();
    let (predecessors: felt*) = alloc();
    let (is_in_queue: felt*) = alloc();
    let (queue: felt*) = alloc();
    init_arrays(
        _distances_len=Vertices,
        _distances=distances,
        _predecessors=predecessors,
        _is_in_queue=is_in_queue,
        _queue=queue,
        _counter=0,
    );

    // Run SPF algorithm
    // (Getting each tokens best predecessor)
    let (new_predecessors: felt*) = shortest_path_faster(
        Vertices,
        distances,
        Vertices,
        is_in_queue,
        1,
        queue,
        Vertices,
        src,
        edge,
        Vertices,
        predecessors,
    );

    let (routers: Router*) = alloc();
    let (amounts: felt*) = alloc();
    let (token_ids: felt*) = alloc();
    let (final_tokens: Path*) = alloc();

    assert amounts[0] = BASE;

    // Determining the Final path we should be taking for the trade
    let (path: felt*) = alloc();
    assert path[0] = new_predecessors[Vertices - 1];
    if (path[0] == 0) {
        assert token_ids[0] = 0;
        assert token_ids[1] = Vertices - 1;

        set_routers_from_edge(1, src, edge, token_ids, routers);

        assert final_tokens[0] = Path(tokens[0], tokens[Vertices - 1]);

        return (
            routers_len=1,
            routers=routers,
            path_len=1,
            path=final_tokens,
            amounts_len=1,
            amounts=amounts,
        );
    }
    assert path[1] = new_predecessors[path[0]];
    if (path[1] == 0) {
        assert token_ids[0] = 0;
        assert token_ids[1] = path[0];
        assert token_ids[2] = Vertices - 1;

        set_routers_from_edge(2, src, edge, token_ids, routers);

        assert final_tokens[0] = Path(tokens[0], tokens[path[0]]);
        assert final_tokens[1] = Path(tokens[path[0]], tokens[Vertices - 1]);

        assert amounts[1] = BASE;

        return (
            routers_len=2,
            routers=routers,
            path_len=2,
            path=final_tokens,
            amounts_len=2,
            amounts=amounts,
        );
    }
    assert path[2] = new_predecessors[path[1]];
    if (path[2] == 0) {
        assert token_ids[0] = 0;
        assert token_ids[1] = path[1];
        assert token_ids[2] = path[0];
        assert token_ids[3] = Vertices - 1;

        set_routers_from_edge(3, src, edge, token_ids, routers);

        assert final_tokens[0] = Path(tokens[0], tokens[path[1]]);
        assert final_tokens[1] = Path(tokens[path[1]], tokens[path[0]]);
        assert final_tokens[2] = Path(tokens[path[0]], tokens[Vertices - 1]);

        assert amounts[1] = BASE;
        assert amounts[2] = BASE;

        return (
            routers_len=3,
            routers=routers,
            path_len=3,
            path=final_tokens,
            amounts_len=3,
            amounts=amounts,
        );
    }
    assert path[3] = new_predecessors[path[2]];
    if (path[3] == 0) {
        assert token_ids[0] = 0;
        assert token_ids[1] = path[2];
        assert token_ids[2] = path[1];
        assert token_ids[3] = path[0];
        assert token_ids[4] = Vertices - 1;

        set_routers_from_edge(4, src, edge, token_ids, routers);

        assert final_tokens[0] = Path(tokens[0], tokens[path[2]]);
        assert final_tokens[1] = Path(tokens[path[2]], tokens[path[1]]);
        assert final_tokens[2] = Path(tokens[path[1]], tokens[path[0]]);
        assert final_tokens[3] = Path(tokens[path[0]], tokens[Vertices - 1]);

        assert amounts[1] = BASE;
        assert amounts[2] = BASE;
        assert amounts[3] = BASE;

        return (
            routers_len=4,
            routers=routers,
            path_len=4,
            path=final_tokens,
            amounts_len=4,
            amounts=amounts,
        );
    }
    // Should never happen
    assert 0 = 1;
    return (0, routers, 0, final_tokens, 0, amounts);
}

// @notice SPF algortihm logic
// @param _distances - An array of "distance" for each vertex to the origin
// @param _is_in_queue - An array of bools that is used to determine whether a vertex is currently in the spf queue
// @param _queue - An array of tokens that makes up the spf queue
// @param _vertices - number of vercies/routers in the graph
// @param _src - array of Edge ranges. Used to map edges to a vertice
// @param _edge - array of graph Edges
// @param _predecessors - array that contains the vertices of the shortest path
func shortest_path_faster{
    syscall_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    _distances_len: felt,
    _distances: felt*,
    _is_in_queue_len: felt,
    _is_in_queue: felt*,
    _queue_len: felt,
    _queue: felt*,
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
    let (new_queue: felt*) = alloc();
    let (src_nr: felt) = Array.shift(_queue_len - 1, new_queue, _queue_len, _queue, 0, 0);
    tempvar new_queue_len = _queue_len - 1;

    // Mark the removed entry as not being in the queue anymore
    let (new_is_in_queue: felt*) = alloc();
    Array.update(
        _new_arr_len=_is_in_queue_len,
        _new_arr=new_is_in_queue,
        _arr_len=_is_in_queue_len,
        _arr=_is_in_queue,
        _index=src_nr,
        _new_val=0,
        _counter=0,
    );

    // Get Source from queue Nr
    let current_source: Source* = _src + (src_nr * 2);
    tempvar offset = current_source[0].start;

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

    let (predecessors) = shortest_path_faster(
        _distances_len,
        new_distances,
        _is_in_queue_len,
        new_new_is_in_queue,
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
    _is_in_queue_len: felt,
    _is_in_queue: felt*,
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
    let (new_is_in_queue: felt*) = alloc();

    local is_dst_end = is_le_felt(_vertices - 1, _edge[0].dst);

    if (is_dst_end == 1) {
        // Moving towards the goal token should always improve the distance
        assert new_distance = _current_distance - EXTRA_BASE + _edge[0].weight;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        assert new_distance = _current_distance + _edge[0].weight;
        tempvar range_check_ptr = range_check_ptr;
    }

    let is_old_distance_better = is_le_felt(_distances[_edge[0].dst], new_distance);

    if (is_old_distance_better == 0) {
        // destination vertex weight = origin vertex + edge weight
        Array.update(
            _distances_len, new_distances, _distances_len, _distances, _edge[0].dst, new_distance, 0
        );

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

        let (already_in_queue_or_last_dst) = bitwise_or(_is_in_queue[_edge[0].dst], is_dst_end);

        if (already_in_queue_or_last_dst == 0) {
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
                new_distances,
                _queue_len,
                _queue,
                _is_in_queue_len,
                _is_in_queue,
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
        }
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
    _is_in_queue: felt*,
    _queue: felt*,
    _counter: felt,
) -> () {
    if (_counter == _distances_len) {
        return ();
    }

    if (_counter == 0) {
        assert _distances[0] = 0;  // Source Token
        assert _queue[0] = 0;  // In token is only token in queue
        assert _predecessors[0] = 0;
        assert _is_in_queue[0] = 0;  // In_token will start in queue
        init_arrays(
            _distances_len,
            _distances + 1,
            _predecessors + 1,
            _is_in_queue + 1,
            _queue,
            _counter + 1,
        );
        return ();
    } else {
        assert _distances[0] = MAX_FELT;
        assert _predecessors[0] = 0;
        assert _is_in_queue[0] = 0;
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

// @notice Extract the router type and address from provided edges
// @param _src - An array of Edge ranges. Used to map edges to a vertice
// @param _edge - An array of graph Edges
// @param _tokens - array of tokens that discribe the trading path
// @param _routers - An (empty) array of routers
func set_routers_from_edge{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _src_len: felt, _src: Source*, _edge: Edge*, _tokens: felt*, _routers: Router*
) {
    alloc_locals;

    if (_src_len == 0) {
        return ();
    }

    get_router_and_address(_src, _edge, _tokens, _routers, 0);

    set_routers_from_edge(_src_len - 1, _src, _edge, _tokens + 1, _routers + 2);

    return ();
}

// @notice For a given token trading pair we find the relevant edge and save the router information
// @param _src - An array of Edge ranges. Used to map edges to a vertice
// @param _edge - An array of graph Edges
// @param _tokens - array of tokens that discribe the trading path
// @param _routers - An array of routers that are used for each token pair trade
func get_router_and_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _src: Source*, _edge: Edge*, _tokens: felt*, _routers: Router*, _counter: felt
) {
    alloc_locals;

    local edge_position = _src[_tokens[0]].start + _counter;

    if (_edge[edge_position].dst == _tokens[1]) {
        assert _routers[0] = _edge[edge_position].router;

        return ();
    } else {
        get_router_and_address(_src, _edge, _tokens, _routers, _counter + 1);
        return ();
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
    GraphConstructor.set_high_liq_tokens(_index, _high_liq_tokens);
    return ();
}
