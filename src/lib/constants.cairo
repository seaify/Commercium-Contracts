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

//Once we have deploy scripts again, we should make this storage vars
const JediSwap = 0;
const AlphaRoad = 1;
const SithSwap = 2;
const TenK = 3;
const StarkSwap = 4;

//Factories
const TenKFactory = 3058627768648483736188861640845691030038370042398279097723890937107886215944; //0x06c31f39524388c982045988de3788530605ed08b10389def2e7b1dd09d19308

//@view
//func read_felts{}()->(max_felt: felt, half_max: felt){
//    return(MAX_FELT,HALF_MAX);
//}
