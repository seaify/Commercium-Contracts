%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256

from src.lib.utils import Utils, Router, Path

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

    //Run Gradient Descent

    return (1, routers, 1, path, 1, amounts);
}

@view
func gradient_descent{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (){
    
    //

    //Sum DEX shares to determine last DEX share

    //objective_func()

    //
    return();
}

// ////////////////////////
//       Internal        //
// ////////////////////////

func objective_func{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    total_amount: felt, DEX_shares_len: felt, DEX_shares: felt*, total_received_token_amount: felt
) -> (received_token_amount: felt){
    
    if (DEX_shares_len == 0) {
        return(received_token_amount);
    }

    //Get return token amounts if DEX_shares[0]*total_amount would be traded
    let (DEX_trade_amount: felt) = Utils.felt_fmul(DEX_shares[0],total_amount);
    let received_token_amount = get_amount_out(DEX_trade_amount);

    let final_received_token_amount = objective_func(
        total_amount=total_amount, 
        DEX_shares_len=DEX_shares_len - 1, 
        DEX_shares=DEX_shares + 1, 
        total_received_token_amount=total_received_token_amount + received_token_amount
    )

    return(received_token_amount);
}

func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    router_type: felt
) -> felt {

    //ToDo Check what can be pre-computed (e.g. reserve_1 * 1000)
    if (router_type == 0){
        let feed_amount = _amount_in * 997;
        let numerator = feed_amount * reserve_2;
        let feed_reserve = reserve_1 * 1000;
        let denominator = feed_reserve + feed_amount;
        let amount_out = unsigned_div_rem(numerator, denominator);
        return (amount_out);
    }

    assert 1 = 2;
    return(0);
}

func gradient{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (){
    
    // if type == 0
    // 

    return();
}
