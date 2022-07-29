%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from src.lib.hub import Uni

namespace Solver:

    func get_weight{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(
        _amount_in : Uint256, 
        _amount_in_usd: Uint256,
        _token1: felt, 
        _token2: felt, 
        _router_address: felt, 
        _router_type: felt
        )->(weight:felt):
        alloc_locals

        #If Uni_Interface
        if _router_type == Uni :

            #Get Token Return Amount
            let (path : felt*) = alloc()
            assert path[0] = _token1
            assert path[1] = _token2
            let (amounts_len: felt, amounts_out: Uint256*) = IUni_router.get_amounts_out(_router_address, amountIn=amount_in, path_len=2, path=path)

            #Transform Token Amount to USD Amount
            let (price_out: Uint256) = get_global_price(_token2)
            let (value_out: Uint256) = Utils.fmul(amounts_out[0],price_out,Uint256(base,0))

            #Determine Weight
            let (trade_cost) = uint256_sub(_amount_in,value_out)
            let(route_cost) = Utils.fdiv(trade_cost,_amount_in,Uint256(base,0))

            return(route_cost.low)
        else:
            #There will be more types
            return(9999999999999999999999999)
        end
    end   

end