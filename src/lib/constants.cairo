// SPDX-License-Identifier: MIT

%lang starknet

//Not actual max felt, just a large feasible number for Uint256
const MAX_FELT = 340282366920938463463374607431768211454;
//Half of the number above
const HALF_MAX = 340282366920938463463374607431768211454 / 2;
const BASE = 1000000000000000000;  // 1e18

/////////////////////
//   Router Types  //
/////////////////////

const JediSwap = 0;
const AlphaRoad = 1;
const SithSwap = 2;
const SithSwapStable = 3;


//@view
//func read_felts{}()->(max_felt: felt, half_max: felt){
//    return(MAX_FELT,HALF_MAX);
//}
