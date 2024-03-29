// SPDX-License-Identifier: MIT
// @author FreshPizza
%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.math_cmp import is_le_felt

from src.lib.utils import Utils, Router, Path
from src.lib.constants import BASE, JediSwap, TenK, MAX_FELT, HALF_MAX
from src.lib.router_aggregator import RouterAggregator

from src.interfaces.i_erc20 import IERC20
from src.interfaces.i_router import (IJediRouter, ITenKRouter)
const trade_deadline = 2644328911;  // Might want to increase this or make a parameter

//Temporary event
//Should mostly be made redundant by propper DEX event emissions
@event
func swap_exact_in(amount_in: felt, token_in: felt, dex: felt) {
}

///////////////////////////////////////////////////////////////////////////////////////
//                                                                                   //
//   This contract holds the logic to perform trades on the different StarkNet AMMs  //
//                                                                                   // 
///////////////////////////////////////////////////////////////////////////////////////

////////////////////////
//       Views        //
////////////////////////

// @notice Simulate how many tokens one would receive when performing multiple specified swaps
// @param _routers - An array of routers to be used for the trades
// @param _path - An array of token pairs to trade
// @param _amounts - An array of token amounts (in %) to sell
// @param _amount_in - The initial token to sell
// @return amount_out - The token return amounts for each solver
@view
func simulate_multi_swap{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_in: Uint256,
    ) -> (amount_out: Uint256) {
    alloc_locals;

    // Create Dict to track token balances
    let (local token_balances_start) = default_dict_new(default_value=0);
    let token_balances = token_balances_start;
    // Set initial balance of token_in
    dict_write{dict_ptr=token_balances}(key=_path[0].token_in, new_value=_amount_in.low);

    //The last token traded to should always be the token that the user wants to receive
    tempvar _token_out = _path[_path_len-1].token_out;

    let (amount_out: Uint256, final_token_balances: DictAccess*) = _simulate_multi_swap(
        _routers_len, _routers, _path_len, _path, _amounts_len, _amounts, _token_out, token_balances
    );

    default_dict_finalize(token_balances_start, final_token_balances, 0);

    return (amount_out,);
}

////////////////////////////
//       Externals        //
////////////////////////////

// @notice Perform multiple token swap given a specified trading path
// @param _routers - An array of routers to be used for the trades
// @param _path - An array of token pairs to trade
// @param _amounts - An array of token amounts (in %) to sell
// @param _receiver_address - Address to receive the bought tokens
@external
func multi_swap{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _receiver_address: felt
    ) {
    alloc_locals;

    if (_routers_len == 0) {
        return ();
    }

    let (init_amount: Uint256) = IERC20.balanceOf(_path[0].token_in, _receiver_address);

    let (trade_amount: Uint256) = Utils.fmul(init_amount, Uint256(_amounts[0], 0), Uint256(BASE, 0));

    _swap_exact_in(_routers[0], trade_amount, _path[0].token_in, _path[0].token_out, _receiver_address);
    
    // Log swap
    swap_exact_in.emit(amount_in=trade_amount.low, token_in=_path[0].token_in, dex=_routers[0].address);

    multi_swap(
        _routers_len - 1,
        _routers + 2,
        _path_len,
        _path + 2,
        _amounts_len,
        _amounts + 1,
        _receiver_address
    );

    return ();
}

////////////////////////////
//       Internal         //
////////////////////////////

// @notice Perform a single swap with the exact tokens to sell being specified
// @param _router - The address of the router used for the trade
// @param _amount_in - The number of _token_in to be sould
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param _receiver_address - Address to receive the bought tokens
func _swap_exact_in{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router, 
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _receiver_address: felt
    ) {
    if (_router.type == JediSwap) {
        IERC20.approve(_token_in, _router.address, _amount_in);
        let (path: felt*) = alloc();
        assert path[0] = _token_in;
        assert path[1] = _token_out;
        IJediRouter.swap_exact_tokens_for_tokens(
            _router.address, 
            _amount_in, 
            Uint256(0, 0), 
            2, 
            path, 
            _receiver_address, 
            trade_deadline
        );
        return ();
    }
    if (_router.type == TenK) {
        IERC20.approve(_token_in, _router.address, _amount_in);
        let (path: felt*) = alloc();
        assert path[0] = _token_in;
        assert path[1] = _token_out;
        ITenKRouter.swapExactTokensForTokens(
            _router.address, 
            _amount_in, 
            Uint256(0, 0), 
            2, 
            path, 
            _receiver_address, 
            trade_deadline
        );
        return ();
    } else {
        with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist") {
            assert 1 = 2;
        }
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        return ();
    }
}

// @notice Simulate a single swap with the exact tokens to sell being specified
// @param _router - The address of the router used for the trade
// @param _amount_in - The number of _token_in to be sould
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param amount_out - The exepcted amount of tokens to be received for the trade
func _simulate_swap_exact_in{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router, 
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (amount_out: Uint256) {

    let (amount_out: Uint256) = RouterAggregator.get_router_amount(_amount_in,_token_in,_token_out,_router);

    return(amount_out,);
}

// @notice Simulate how many tokens one would receive when performing multiple specified swaps
// @param _routers - An array of routers to be used for the trades
// @param _path - An array of token pairs to trade
// @param _amounts - An array of token amounts (in %) to sell
// @param _token_out - The address of the final token to buy
// @param _token_balances - A dictionary of token address and their amounts posessed by the function executor
// @return amount_out - The expected received amount of the final token to be bought 
// @return final_token_balances - A dictionary of token addresses and balances that this contract would posess after each consecutive trade 
//         This variable is only used to track the balances during the iterations and should simply be squashed after this function is executed
func _simulate_multi_swap{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _token_out: felt,
        _token_balances: DictAccess*,
    ) -> (amount_out: Uint256, final_token_balances: DictAccess*) {
    alloc_locals;

    if (_routers_len == 0) {
        return (Uint256(0, 0), _token_balances);
    }

    // Determine token amount to trade
    let (current_balance) = dict_read{dict_ptr=_token_balances}(_path[0].token_in);

    let trade_amount = Utils.felt_fmul(current_balance, _amounts[0], BASE);

    // Save new balance of token_in
    tempvar new_token_in_balance = current_balance - trade_amount;
    
    dict_write{dict_ptr=_token_balances}(_path[0].token_in, new_token_in_balance);

    // Simulate individual swap
    let (amount_out: Uint256) = _simulate_swap_exact_in(
        _routers[0], Uint256(trade_amount, 0), _path[0].token_in, _path[0].token_out
    );

    // Save new balance of token_out
    let (current_balance) = dict_read{dict_ptr=_token_balances}(_path[0].token_out);
    tempvar new_token_out_balance = current_balance + amount_out.low;
    dict_write{dict_ptr=_token_balances}(_path[0].token_out, new_token_out_balance);

    let (sum, final_token_balances) = _simulate_multi_swap(
        _routers_len - 1,
        _routers + 2,
        _path_len,
        _path + 2,
        _amounts_len,
        _amounts + 1,
        _token_out,
        _token_balances,
    );

    if (_token_out == _path[0].token_out) {
        let (final_sum: Uint256, _) = uint256_add(amount_out, sum);
        return (final_sum, final_token_balances);
    }else{
        let (final_sum: Uint256, _) = uint256_add(Uint256(0,0), sum);
        return (final_sum, final_token_balances);
    }
}
