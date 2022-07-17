%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.hub import Swap

@contract_interface
namespace ITrade_executor:

    func swap_single(_router_address: felt, _amount_in: Uint256,_token_in: felt,_token_out: felt, _reciever: felt
        ) -> (amount_out: Uint256):
    end

    func multis_swap(
        _path_len: felt,
        _path: Swap*,
        _trade_executor_address: felt,
        _receiver_address: felt):
    end

end
