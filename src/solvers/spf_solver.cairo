%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256,uint256_le,uint256_eq,uint256_add,uint256_sub,uint256_mul,uint256_signed_div_rem,uint256_unsigned_div_rem)

from src.lib.array import Array
from src.lib.utils import Utils
from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.ITrade_executor import ITrade_executor
from src.interfaces.IERC20 import IERC20

const Vertices = 6
const Edges = 21
const LARGE_VALUE = 850705917302346000000000000000000000000000000 

const base = 1000000000000000000 # 1e18
const extra_base = 10 # We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

#Token addresses
const USDT = 12345
const USDC = 12346
const DAI = 12347
const ETH = 12348

# Storage Setup
#  src[0] [0, 2]:
#  src[1] [2, 3]: 
#
#  -> dst: 0src -> 0:[123]   -> weight  -> pool
#          0src -> 1:[2323]
#          1src -> 2:[23543]
#          1src -> 3:[23133]
#          1src -> 4:[2323]

@storage_var
func router_aggregator() -> (router_aggregator_address: felt):
end

@storage_var
func trade_executor() -> (trade_executor_address: felt):
end

struct Trade_Pair:
    member asset : felt
    member pool : felt
end

struct Source:
    member start : felt
    member stop : felt
end

#
#Views
#

@view
func get_results{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,range_check_ptr}(
    _amount_in: Uint256,
    _token_in: felt,
    _token_out: felt)
    -> (
    res1: felt,res2: felt,res3: felt,res4: felt,res5: felt,res6: felt):
    alloc_locals
    
    let (tokens : felt*) = alloc()
    assert tokens[0] = _token_in

    #HardCodeTheFollowing (Or read from storage)
    assert tokens[1] = ETH
    assert tokens[2] = DAI
    assert tokens[3] = USDC 
    assert tokens[4] = USDT

    assert tokens[5] = _token_out

    #Edge, this is not a Struct because we cannot pass structs that have pointers in them.
    let (src : Source*) = alloc()
    let (dst : felt*) = alloc()
    let (weight : felt*) = alloc()
    let (pool : felt*) = alloc()

    #transform input amount to USD amount
    let (router_aggregator_address) = router_aggregator.read()
    let (price: Uint256) = IRouter_aggregator.get_global_price(router_aggregator_address,tokens[0])
    let (amount_in: Uint256) = Utils.fmul(price,_amount_in,Uint256(base,0))

    #We use _dst_len to count the number of legit source to destination edges
    set_edges(_amount_in,6,tokens,Vertices,src,_dst_len=0,_dst=dst,_weight_len=0,_weight=weight,_pool_len=0,_pool=pool,_dst_counter=1,_src_counter=0,_total_counter=0)

    #Initialize inQueue Array to false
    let (distances : felt*) = alloc()
    let (predecessors : felt*) = alloc()
    let (is_in_queue : felt*) = alloc()
    let (queue: felt*) = alloc()
    init_arrays(6,distances,6,predecessors,6,is_in_queue,queue)

    #determine shortest path
    let (new_distances: felt*) = shortest_path_faster(6,distances,6,is_in_queue,1,queue,Vertices,src,5,dst,0,weight)

    return(new_distances[0],new_distances[1],new_distances[2],new_distances[3],new_distances[4],new_distances[5])
end

#
#Internals
#

#@notice 
#We use _dst_len to track every src->dst edge that is not 0
#We use _dst_counter to track the number of destinations we have checked for each source (We check vertices 1-5)
#We use _src_couter to track the number of sources we have checked (We check vertices 0-4)
func set_edges{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in : Uint256, 
    _tokens_len:felt,
    _tokens:felt*,
    _src_len:felt,
    _src:Source*,
    _dst_len:felt,
    _dst:felt*,
    _weight_len:felt,
    _weight:felt*,
    _pool_len:felt,
    _pool:felt*,
    _dst_counter:felt,
    _src_counter:felt,
    _total_counter: felt
    )->():
    
    alloc_locals
    
    if _src_counter == Vertices - 1:
	    return()
    end

    local is_start_token
    local is_same_token
    local we_are_not_advancing

    if _dst_counter == _src_counter :
	    assert is_same_token = 1
    else:
        assert is_same_token = 0
    end

    #We don't need to set edges where the source is the last token
    if is_same_token == 1 :
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert we_are_not_advancing = 0
    else:
        let (router_aggregator_address) = router_aggregator.read()
        let (amount_out: Uint256, router_address: felt, router_type: felt) = IRouter_aggregator.get_single_best_pool(router_aggregator_address,_amount_in,_tokens[_src_counter],_tokens[_dst_counter])
	    let (amount_is_zero) = uint256_eq(amount_out,Uint256(0,0))

        if amount_is_zero == 1 :
            #Edge(Destination_List(dst,dst,dst,dst,dst),Weight_List(weight,weight,weight,weight,weight),Pool_List(pool,pool,pool,pool,pool))
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            assert we_are_not_advancing = 1
        else:
            assert _dst[0] = _dst_counter
            let(weight:felt) = IRouter_aggregator.get_weight(router_aggregator_address,_amount_in,_tokens[_src_counter],_tokens[_dst_counter],router_address,router_type)
            assert _weight[0] = weight
            assert _pool[0] = router_address
            assert we_are_not_advancing = 0
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
	    tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    
    if _dst_counter == Vertices - 1:
        tempvar next_dst = we_are_not_advancing + is_same_token
        if next_dst != 0 :
            assert _src[0] = Source(_total_counter, _dst_len)
	        set_edges(
                _amount_in,
                6,
                _tokens,
                _src_len,
                _src+2, #+2 because our struct consists of 2 felts
                0, # _dst_len
                _dst,
                _weight_len,
                _weight,
                _pool_len,
                _pool,
                _dst_counter=1,
                _src_counter=_src_counter+1,
                _total_counter=_total_counter+_dst_len
            )    
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            assert _src[0] = Source(_total_counter, _dst_len+1)
            set_edges(
                _amount_in,
                6,
                _tokens,
                _src_len,
                _src+2, #+2 because our struct consists of 2 felts
                0, # _dst_len
                _dst+1,
                _weight_len,
                _weight+1,
                _pool_len,
                _pool+1,
                _dst_counter=1,
                _src_counter=_src_counter+1,
                _total_counter=_total_counter+_dst_len+1
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    else:
	    tempvar next_dst = we_are_not_advancing + is_same_token
        if next_dst != 0 :
            #We are not advancing the edge errays
            set_edges(
                _amount_in,
                6,
                _tokens,
                _src_len,
                _src,
                _dst_len,
                _dst,
                _weight_len,
                _weight,
                _pool_len,
                _pool,
                _dst_counter=_dst_counter+1,
                _src_counter=_src_counter,
                _total_counter=_total_counter
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            #We are advancing the edge arrays
            set_edges(
                _amount_in,
                6,
                _tokens,
                _src_len,
                _src,
                _dst_len+1,
                _dst+1,
                _weight_len,
                _weight+1,
                _pool_len,
                _pool+1,
                _dst_counter=_dst_counter+1,
                _src_counter=_src_counter,
                _total_counter=_total_counter
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    	tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return()
end

func shortest_path_faster{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _distances_len:felt,
    _distances:felt*,
    _is_in_queue_len:felt,
    _is_in_queue:felt*,
    _queue_len:felt,
    _queue:felt*,
    _src_len: felt,
    _src: Source*,
    _dst_len: felt,
    _dst: felt*,
    _weight_len: felt,
    _weight: felt*) -> (final_distances: felt*):

    alloc_locals

    #If there is no destination left in the queue we can stop the procedure
    if _queue_len == 0 :
        return(_distances)
    end    

    #Get first entry from queue
    let (new_queue : felt*) = alloc()
    let (src_nr: felt) = Array.shift(_queue_len-1,new_queue,_queue_len,_queue,0,0)
    tempvar new_queue_len = _queue_len - 1

    #Mark the removed entry as not being in the queue anymore
    let (new_is_in_queue : felt*) = alloc()
    Array.update(_is_in_queue_len,new_is_in_queue,_is_in_queue_len,_is_in_queue,1,0,0)

    #Get Source from queue Nr
    let current_source: Source* = _src + src_nr
    tempvar offset = current_source[0].start

    let (current_distance: felt) = Array.get_at_index(
        _distances_len, 
        _distances,
        src_nr, 
        0
    )

    #Determine if there is a shorter distance to its different destinations
    let (_,new_distances: felt*,new_new_queue_len,new_new_queue: felt*,new_new_is_in_queue_len: felt,new_new_is_in_queue: felt*) = determine_distances(_distances_len, _distances, new_queue_len, new_queue, _is_in_queue_len, new_is_in_queue, 0, _dst + offset, 0,_weight + offset, current_source[0].stop,current_distance)
    
    let (final_distances) = shortest_path_faster(_distances_len,new_distances,new_new_is_in_queue_len,new_new_is_in_queue,new_new_queue_len,new_new_queue,Vertices,_src,5,_dst,0,_weight)

    return(final_distances)
end     

func determine_distances{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _distances_len: felt,
    _distances: felt*, 
    _queue_len: felt, 
    _queue: felt*, 
    _is_in_queue_len: felt, 
    _is_in_queue: felt*, 
    _dst_len: felt, 
    _dst: felt*, 
    _weight_len: felt, 
    _weight: felt*, 
    _dst_stop:felt, 
    _current_distance: felt) -> (_distances_len: felt,_distances: felt*,_queue_len: felt,_queue: felt*,_is_in_queue_len: felt,_is_in_queue: felt*):
    
    alloc_locals

    if _dst_stop == 0:
        #We end the procedure if all destinations have been evaluated
        return(_distances_len,_distances,_queue_len,_queue,_is_in_queue_len,_is_in_queue)
    end
   
    let (new_distances : felt*) = alloc()
    local new_queue_len : felt
    local new_distance : felt
    let (new_queue : felt*) = alloc()
    let (new_is_in_queue : felt*) = alloc()

    if _dst[0] == 5 :
        #Moving towards the goal token should always improve the distance
        assert new_distance = _current_distance / extra_base + _weight[0]
    else:
        #We add an extra base, so that we can remove it again for the move to the goal vertex. (see above)
        assert new_distance = _current_distance + (_weight[0] * extra_base)
    end

    let (is_new_distance_better) = is_le_felt(_distances[_dst[0]], new_distance)

    if is_new_distance_better == 0:
        #destination vertex weight = origin vertex + edge weight
        Array.update(_distances_len,new_distances,_distances_len,_distances,_dst[0], new_distance,0)

        if _is_in_queue[_dst[0]] == 0 :
            #Add new vertex with better weight to queue
            Array.push(_queue_len+1,new_queue,_queue_len,_queue,_dst[0])
            assert new_queue_len = _queue_len + 1

            Array.update(_is_in_queue_len,new_is_in_queue,_is_in_queue_len,_is_in_queue,_dst[0],1,0)

            let (
                res_distance_len,
                res_distance,
                res_queue_len,
                res_queue,
                res_is_in_queue_len,
                res_is_in_queue
            ) = determine_distances(
                _distances_len, 
                new_distances, 
                new_queue_len, 
                new_queue, 
                _is_in_queue_len, 
                new_is_in_queue, 
                _dst_len, 
                _dst+1, 
                _weight_len, 
                _weight+1, 
                _dst_stop-1, 
                _current_distance
            )
            return(res_distance_len,res_distance,res_queue_len,res_queue,res_is_in_queue_len,res_is_in_queue)
        else:
            let (
                res_distance_len,
                res_distance,
                res_queue_len,
                res_queue,
                res_is_in_queue_len,
                res_is_in_queue
            ) = determine_distances(
                _distances_len, 
                new_distances, 
                _queue_len, 
                _queue, 
                _is_in_queue_len, 
                _is_in_queue, 
                _dst_len, 
                _dst+1, 
                _weight_len, 
                _weight+1, 
                _dst_stop-1, 
                _current_distance
            )
            return(res_distance_len,res_distance,res_queue_len,res_queue,res_is_in_queue_len,res_is_in_queue)
        end
    else:
        let (
            res_distance_len,
            res_distance,
            res_queue_len,
            res_queue,
            res_is_in_queue_len,
            res_is_in_queue
        ) = determine_distances(
            _distances_len, 
            _distances, 
            _queue_len, 
            _queue, 
            _is_in_queue_len, 
            _is_in_queue, 
            _dst_len, 
            _dst+1, 
            _weight_len, 
            _weight+1, 
            _dst_stop-1,
            _current_distance
        )

        return(res_distance_len,res_distance,res_queue_len,res_queue,res_is_in_queue_len,res_is_in_queue)
    end
end

func init_arrays{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _distances_len:felt,_distances:felt*,_predecessors_len:felt,_predecessors:felt*,_is_queue_len:felt,_is_in_queue:felt*,_queue:felt*) -> ():
    
    #Always of length V
    assert _distances[0] = 0 #Source Token 
    assert _distances[1] = 850705917302346000000000000000000000000000000
    assert _distances[2] = 850705917302346000000000000000000000000000000
    assert _distances[3] = 850705917302346000000000000000000000000000000
    assert _distances[4] = 850705917302346000000000000000000000000000000
    assert _distances[5] = 850705917302346000000000000000000000000000000

    assert _predecessors[0] = 0 
    assert _predecessors[1] = 0
    assert _predecessors[2] = 0
    assert _predecessors[3] = 0
    assert _predecessors[4] = 0
    assert _predecessors[5] = 0

    assert _is_in_queue[0] = 0 # In_token will start in queue
    assert _is_in_queue[1] = 0 
    assert _is_in_queue[2] = 0
    assert _is_in_queue[3] = 0
    assert _is_in_queue[4] = 0
    assert _is_in_queue[5] = 0

    assert _queue[0] = 0 # In token is only token in queue
    
    return()
end

#
#Admin
#

@external
func set_router_aggregator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_router_aggregator_address: felt):
    router_aggregator.write(_new_router_aggregator_address)
    return()
end
