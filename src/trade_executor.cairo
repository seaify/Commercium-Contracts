%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.math_cmp import is_le_felt

from src.openzeppelin.security.safemath import SafeUint256
from src.lib.utils import Utils, Router, Path
from src.lib.constants import BASE, AlphaRoad, JediSwap, SithSwap, SithSwapStable, MAX_FELT, HALF_MAX
from src.lib.router_aggregator import RouterAggregator

from src.interfaces.IERC20 import IERC20
from src.interfaces.IRouter import (IJedi_router, IAlpha_router, ISith_router)
from src.interfaces.IFactory import IAlpha_factory
from src.interfaces.IPool import IAlpha_pool
const trade_deadline = 2644328911;  // Might want to increase this or make a parameter

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

    let (amount_out: Uint256, final_token_balances: DictAccess*) = _simulate_multi_swap(
        _routers_len, _routers, _path_len, _path, _amounts_len, _amounts, token_balances
    );

    default_dict_finalize(token_balances_start, final_token_balances, 0);

    return (amount_out,);
}

@view
func simulate_multi_swap_exact_out{
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
        _amount_out: Uint256,
    ) -> (amount_in: Uint256) {
    alloc_locals;

    // Create Dict to track token balances
    let (local token_balances_start) = default_dict_new(default_value=0);
    let token_balances = token_balances_start;

    // Set initial balance of token_out
    dict_write{dict_ptr=token_balances}(key=_path[0].token_out, new_value=_amount_out.low);

    let (amount_in: Uint256, final_token_balances: DictAccess*) = _simulate_multi_swap_exact_out(
        _routers_len, _routers, _path_len, _path, _amounts_len, _amounts, token_balances
    );

    //Squash Dict
    default_dict_finalize(token_balances_start, final_token_balances, 0);

    return (amount_in,);
}

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

    let (trade_amount) = Utils.fmul(init_amount, Uint256(_amounts[0], 0), Uint256(BASE, 0));

    _swap_exact_in(_routers[0], trade_amount, _path[0].token_in, _path[0].token_out, _receiver_address);

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

@external
func multi_swap_exact_out{
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
        _receiver_address: felt,
        _amount_out: Uint256
    ) {
    alloc_locals;

    if (_routers_len == 0) {
        return ();
    }

    let (current_amount: Uint256) = IERC20.balanceOf(_path[0].token_out, _receiver_address);

    let (amount_to_still_trade) = uint256_sub(_amount_out,current_amount);

    let (trade_amount) = Utils.fmul(amount_to_still_trade, Uint256(_amounts[0], 0), Uint256(BASE, 0));

    _swap_exact_out(_routers[0], trade_amount, _path[0].token_in, _path[0].token_out, _receiver_address);

    multi_swap_exact_out(
        _routers_len - 1,
        _routers + 2,
        _path_len,
        _path + 2,
        _amounts_len,
        _amounts + 1,
        _receiver_address,
        _amount_out
    );

    return ();
}

//
// Internal
//

//Perform swap given an exact input amount
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
        //Writing to storage is expensive, so we check current allowance level before re-approving transfer
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == TRUE) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            IJedi_router.swap_exact_tokens_for_tokens(
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
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            IJedi_router.swap_exact_tokens_for_tokens(
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
    }
    if (_router.type == AlphaRoad){
        //Writing to storage is expensive, so we check current allowance level before re-approving transfer
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == TRUE) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        IAlpha_router.swapExactTokensForTokens(
            _router.address,
            _token_in,
            _token_out,
            _amount_in,
            Uint256(0,0)
        ); 
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        return ();
    }
    if (_router.type == SithSwap) {
        //Writing to storage is expensive, so we check current allowance level before re-approving transfer
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        //Depending on the token we might want 

        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == TRUE) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            ISith_router.swapExactTokensForTokensSimple(
                _router.address, 
                _amount_in, 
                Uint256(0, 0), 
                _token_in,
                _token_out,
                0,
                _receiver_address, 
                trade_deadline
            );
            return ();
        } else {
            ISith_router.swapExactTokensForTokensSimple(
                _router.address, 
                _amount_in, 
                Uint256(0, 0), 
                _token_in,
                _token_out,
                0,
                _receiver_address, 
                trade_deadline
            );
            return ();
        }
    } 
    if (_router.type == SithSwapStable) {
        //Writing to storage is expensive, so we check current allowance level before re-approving transfer
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        //Depending on the token we might want 

        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == TRUE) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            ISith_router.swapExactTokensForTokensSimple(
                _router.address, 
                _amount_in, 
                Uint256(0, 0), 
                _token_in,
                _token_out,
                1,
                _receiver_address, 
                trade_deadline
            );
            return ();
        } else {
            ISith_router.swapExactTokensForTokensSimple(
                _router.address, 
                _amount_in, 
                Uint256(0, 0), 
                _token_in,
                _token_out,
                1,
                _receiver_address, 
                trade_deadline
            );
            return ();
        }
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

//Perform swap given an exact output amount
func _swap_exact_out{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router, 
        _amount_out: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _receiver_address: felt
    ) {
    if (_router.type == JediSwap) {
        //Writing to storage is expensive, so we check current allowance level before re-approving transfer
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == 0) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            IJedi_router.swap_tokens_for_exact_tokens(
                _router.address,
                _amount_out,
                Uint256(MAX_FELT, 0),
                2,
                path,
                _receiver_address, 
                trade_deadline
            );
            return ();
        } else {
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            IJedi_router.swap_tokens_for_exact_tokens(
                _router.address,
                _amount_out,
                Uint256(MAX_FELT, 0),
                2,
                path,
                _receiver_address, 
                trade_deadline
            );
            return ();
        }
    }
    if (_router.type == AlphaRoad){
        let (this_address) = get_contract_address();
        let (allowance) = IERC20.allowance(_token_in,this_address,_router.address);
        let is_below_threshold = is_le_felt(allowance.low,HALF_MAX);
        if (is_below_threshold == 0) {
            IERC20.approve(_token_in, _router.address, Uint256(MAX_FELT,0));
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        IAlpha_router.swapTokensForExactTokens(
            _router.address,
            _token_in,
            _token_out,
            _amount_out,
            Uint256(MAX_FELT, 0)
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

func _simulate_swap_exact_out{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router, 
        _amount_out: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (amount_out: Uint256) {

    let (amount_out: Uint256) = RouterAggregator.get_router_amount_in(_amount_out,_token_in,_token_out,_router);

    return(amount_out,);
}

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
        _token_balances: DictAccess*,
    ) -> (amount_out: Uint256, final_token_balances: DictAccess*) {
    alloc_locals;

    if (_routers_len == 0) {
        return (Uint256(0, 0), _token_balances);
    }

    // Determine token amount to trade
    let (current_balance) = dict_read{dict_ptr=_token_balances}(_path[0].token_in);
    let (trade_amount) = Utils.felt_fmul(current_balance, _amounts[0], BASE);

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
        _token_balances,
    );

    let (final_sum: Uint256, _) = uint256_add(amount_out, sum);

    return (final_sum, final_token_balances);
}

func _simulate_multi_swap_exact_out{
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
        _token_balances: DictAccess*,
    )->(amount_in: Uint256, final_token_balances: DictAccess*) {
    alloc_locals;

    if (_routers_len == 0) {
        return (Uint256(0, 0), _token_balances);
    }

    // Determine token amount to trade
    let (current_balance) = dict_read{dict_ptr=_token_balances}(_path[0].token_out);
    let (trade_amount) = Utils.felt_fmul(current_balance, _amounts[0], BASE);

    // Save new balance of token_in
    tempvar new_token_out_balance = current_balance - trade_amount;
    dict_write{dict_ptr=_token_balances}(_path[0].token_out, new_token_out_balance);

    // Simulate individual swap
    let (amount_in: Uint256) = _simulate_swap_exact_out(
        _routers[0], Uint256(trade_amount, 0), _path[0].token_in, _path[0].token_out
    );

    // Save new balance of token_out
    let (current_balance) = dict_read{dict_ptr=_token_balances}(_path[0].token_in);
    tempvar new_token_in_balance = current_balance + amount_in.low;
    dict_write{dict_ptr=_token_balances}(_path[0].token_in, new_token_in_balance);

    let (sum, final_token_balances) = _simulate_multi_swap(
        _routers_len - 1,
        _routers + 2,
        _path_len,
        _path + 2,
        _amounts_len,
        _amounts + 1,
        _token_balances,
    );

    let (final_sum: Uint256, _) = uint256_add(amount_in, sum);

    return (final_sum, final_token_balances);
}
