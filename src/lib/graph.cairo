// SPDX-License-Identifier: MIT
/// @author FreshPizza
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq

from src.lib.utils import Router
from src.interfaces.i_router_aggregator import IRouterAggregator
from src.lib.constants import BASE

const EXTRA_BASE = BASE * 100;

from openzeppelin.access.ownable.library import Ownable

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                             //
//                  Graph building library focused on building a graph of DEXes to be used within the Commercium               //
//                                                                                                                             // 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////
//  Storage Setup  //
/////////////////////
//
//  src[0] [0, 2]:
//  src[1] [2, 3]:
//
//  -> dst: 0src -> 0:[123]   -> weight  -> pool
//          0src -> 1:[2323]
//          1src -> 2:[23543]
//          1src -> 3:[23133]
//          1src -> 4:[2323]

@storage_var
func router_aggregator() -> (router_aggregator_address: felt) {
}

@storage_var
func high_liq_tokens(index: felt) -> (token: felt) {
}

struct Source {
    start: felt,
    stop: felt,
}

struct Edge {
    dst: felt,
    router: Router,
    weight: felt,
}

namespace GraphConstructor {

    /////////////////////////////
    //       Constructor       //
    /////////////////////////////

    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _owner: felt, _router_aggregator: felt
    ) {
        Ownable.initializer(_owner);
        router_aggregator.write(_router_aggregator);
        return ();
    }

    /////////////////////////
    //       Interals      //
    /////////////////////////

    // @notice Generate graph that will be used for the spf algorithm
    // @param _amount_in - The amount of the token that a user wants to sell
    // @param _amount_in_usd - The amount of the token that a user wants to sell (is used to set weights)
    // @param _vertices - number of vercies/routers in the graph
    // @param _tokens - array of tokens/vertices that make up the graph
    // @param _src - array of Edge ranges. Used to map edges to a vertice
    // @param _edge - array of graph Edges
    // @param _dst_counter - counter used to iterate through destination vertices for each source vertex
    // @param _src_counter - counter used to iterate through the source vertices/tokens
    // @param _total_counter - counter used to find the correct start of each vertex in the Edge array
    func build_graph{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _amount_in_usd: Uint256,
        _vertices: felt,
        _tokens: felt*,
        _src_len: felt,
        _src: Source*,
        _edge_len: felt,
        _edge: Edge*,
        _dst_counter: felt,
        _src_counter: felt,
        _total_counter: felt,
    ) -> () {
        alloc_locals;

        if (_src_counter == _vertices - 1) {
            return ();
        }

        local is_start_token;
        local is_same_token;
        local we_are_not_advancing;

        if (_dst_counter == _src_counter) {
            assert is_same_token = 1;
        } else {
            assert is_same_token = 0;
        }

        // We don't need to set edges where the source is the last token
        if (is_same_token == 1) {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            assert we_are_not_advancing = 0;
        } else {
            let (router_aggregator_address) = router_aggregator.read();
            let (
                local amount_out: Uint256, local router: Router
            ) = IRouterAggregator.get_single_best_router(
                router_aggregator_address, _amount_in, _tokens[_src_counter], _tokens[_dst_counter]
            );
            let (amount_is_zero) = uint256_eq(amount_out, Uint256(0, 0));
            if (amount_is_zero == 1) {
                // Edge(Destination_List(dst,dst,dst,dst,dst),Weight_List(weight,weight,weight,weight,weight),Pool_List(pool,pool,pool,pool,pool))
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
                assert we_are_not_advancing = 1;
            } else {
                let (local weight: felt) = IRouterAggregator.get_weight(
                    router_aggregator_address, _amount_in_usd, amount_out, _tokens[_dst_counter]
                );
                if (_src_counter == 0) {
                    assert _edge[0] = Edge(_dst_counter, router, weight + EXTRA_BASE);
                } else {
                    assert _edge[0] = Edge(_dst_counter, router, weight);
                }
                assert we_are_not_advancing = 0;
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        if (_dst_counter == _vertices - 1) {
            tempvar next_dst = we_are_not_advancing + is_same_token;
            if (next_dst != 0) {
                assert _src[0] = Source(_total_counter, _edge_len);
                build_graph(
                    _amount_in,
                    _amount_in_usd,
                    _vertices,
                    _tokens,
                    _src_len,
                    _src + 2,
                    0,
                    _edge,
                    _dst_counter=1,
                    _src_counter=_src_counter + 1,
                    _total_counter=_total_counter + _edge_len,
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            } else {
                assert _src[0] = Source(_total_counter, _edge_len + 1);
                build_graph(
                    _amount_in,
                    _amount_in_usd,
                    _vertices,
                    _tokens,
                    _src_len,
                    _src + 2,
                    0,
                    _edge + 4,
                    _dst_counter=1,
                    _src_counter=_src_counter + 1,
                    _total_counter=_total_counter + _edge_len + 1,
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }
        } else {
            tempvar next_dst = we_are_not_advancing + is_same_token;
            if (next_dst != 0) {
                // We are not advancing the edge erray
                build_graph(
                    _amount_in,
                    _amount_in_usd,
                    _vertices,
                    _tokens,
                    _src_len,
                    _src,
                    _edge_len,
                    _edge,
                    _dst_counter=_dst_counter + 1,
                    _src_counter=_src_counter,
                    _total_counter=_total_counter,
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            } else {
                // We are advancing the edge array
                build_graph(
                    _amount_in,
                    _amount_in_usd,
                    _vertices,
                    _tokens,
                    _src_len,
                    _src,
                    _edge_len + 1,
                    _edge + 4,
                    _dst_counter=_dst_counter + 1,
                    _src_counter=_src_counter,
                    _total_counter=_total_counter,
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        return ();
    }

    // @notice From a given input and output token we construct an array of relevant tokens/vertices that will
    //         be considered when building the graph
    // @param _token_in - Token sold / Origin vertex
    // @param _token_out - Token bought / Destination vertex
    // @param _tokens - An (empty) array of tokens that will be used as the arr of vertices
    // @param _liq_counter - Tracker of stored liquidations tokens that we have added to the tokens/vertex array
    // @param _counter - General counter to track the iteration through this function
    func construct_vertices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_in: felt, _token_out: felt, _tokens: felt*, _liq_counter: felt, _counter: felt
    ) -> (vertices: felt) {
        let (high_liq_token) = high_liq_tokens.read(_liq_counter);

        if (high_liq_token == 0) {
            assert _tokens[0] = _token_out;
            return (_counter,);
        }

        if (_token_in == high_liq_token) {
            let (total_vertices) = construct_vertices(
                _token_in, _token_out, _tokens, _liq_counter + 1, _counter
            );
            return (total_vertices,);
        }

        if (_token_out == high_liq_token) {
            let (total_vertices) = construct_vertices(
                _token_in, _token_out, _tokens, _liq_counter + 1, _counter
            );
            return (total_vertices,);
        }

        assert _tokens[0] = high_liq_token;
        let (total_vertices) = construct_vertices(
            _token_in, _token_out, _tokens + 1, _liq_counter + 1, _counter + 1
        );
        return (total_vertices,);
    }

    ////////////////////////
    //       Admin        //
    ////////////////////////

    // @notice Store a token that is considered as liquid and will always be part of the array of vertices
    // @dev admin function that can be used to override existing mappings or add a new high liquidity token.
    //      The high_liq_tokens mapping is used as an array. So the admin has to ensure that there is no gap 
    //      in the list of indices.
    // @param _index - Token sold / Origin vertex
    // @param _high_liq_tokens - Token bought / Destination vertex
    func set_high_liq_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _index: felt, _high_liq_tokens: felt
    ) {
        Ownable.assert_only_owner();
        high_liq_tokens.write(_index, _high_liq_tokens);
        return ();
    }

}


