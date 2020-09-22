/*
 * Copyright 2018-2019 CryptoGraphics <CrGr@protonmail.com>.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version. See LICENSE for more details.
 */

uint __attribute__((overloadable)) amd_bitalign(uint src0, uint src1, uint src2)
{
	uint dstx = 0;
	uint dsty = 0;
    __asm ("v_alignbit_b32 %[dstx], %[src0x], %[src1x], %[src2x]\n"
          : [dstx] "=&v" (dstx)
          : [src0x] "v" (src0), [src1x] "v" (src1), [src2x] "v" (src2));
	return (uint) (dstx);
}
uint __attribute__((overloadable)) amd_bytealign(uint src0, uint src1, uint src2)
{
	uint dstx = 0;
	uint dsty = 0;
    __asm ("v_alignbyte_b32 %[dstx], %[src0x], %[src1x], %[src2x]\n"
          : [dstx] "=&v" (dstx)
          : [src0x] "v" (src0), [src1x] "v" (src1), [src2x] "v" (src2));
	return (uint) (dstx);
}

#define rotr64(x, n) ((n) < 32 ? (amd_bitalign((uint)((x) >> 32), (uint)(x), (uint)(n)) | ((ulong)amd_bitalign((uint)(x), (uint)((x) >> 32), (uint)(n)) << 32)) : (amd_bitalign((uint)(x), (uint)((x) >> 32), (uint)(n) - 32) | ((ulong)amd_bitalign((uint)((x) >> 32), (uint)(x), (uint)(n) - 32) << 32)))

#define Gfunc(a,b,c,d) \
{ \
    a += b;  \
    d ^= a; \
    d = rotr64(d, 32); \
 \
    c += d;  \
    b ^= c; \
    b = rotr64(b, 24); \
 \
    a += b;  \
    d ^= a; \
    d = rotr64(d, 16); \
 \
    c += d; \
    b ^= c; \
    b = rotr64(b, 63); \
}

#define roundLyra(state) \
{ \
     Gfunc(state[0].x, state[2].x, state[4].x, state[6].x); \
     Gfunc(state[0].y, state[2].y, state[4].y, state[6].y); \
     Gfunc(state[1].x, state[3].x, state[5].x, state[7].x); \
     Gfunc(state[1].y, state[3].y, state[5].y, state[7].y); \
 \
     Gfunc(state[0].x, state[2].y, state[5].x, state[7].y); \
     Gfunc(state[0].y, state[3].x, state[5].y, state[6].x); \
     Gfunc(state[1].x, state[3].y, state[4].x, state[6].y); \
     Gfunc(state[1].y, state[2].x, state[4].y, state[7].x); \
}

#define SHUFFLE_0(s) \
    { \
      uint2 s1, s2, s3; \
      s1 = as_uint2(s[1]); \
      s2 = as_uint2(s[2]); \
      s3 = as_uint2(s[3]); \
		__asm ( \
	     "s_nop 1\n" \
		  "v_mov_b32_dpp  %[ds1x], %[s1x] quad_perm:[1,2,3,0]\n" \
        "v_mov_b32_dpp  %[ds1y], %[s1y] quad_perm:[1,2,3,0]\n" \
        "v_mov_b32_dpp  %[ds2x], %[s2x] quad_perm:[2,3,0,1]\n" \
        "v_mov_b32_dpp  %[ds2y], %[s2y] quad_perm:[2,3,0,1]\n" \
        "v_mov_b32_dpp  %[ds3x], %[s3x] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds3y], %[s3y] quad_perm:[3,0,1,2]\n" \
		  "s_nop 1\n" \
		  : [ds1x] "=&v" (s1.x), \
          [ds1y] "=&v" (s1.y), \
		    [ds2x] "=&v" (s2.x), \
          [ds2y] "=&v" (s2.y), \
          [ds3x] "=&v" (s3.x), \
          [ds3y] "=&v" (s3.y) \
		  : [s1x] "0" (s1.x), \
          [s1y] "1" (s1.y), \
		    [s2x] "2" (s2.x), \
          [s2y] "3" (s2.y), \
          [s3x] "4" (s3.x), \
          [s3y] "5" (s3.y)); \
        s[1] = as_ulong(s1); \
        s[2] = as_ulong(s2); \
        s[3] = as_ulong(s3); \
	}

#define SHUFFLE_1(s) \
    { \
      uint2 s1, s2, s3; \
      s1 = as_uint2(s[1]); \
      s2 = as_uint2(s[2]); \
      s3 = as_uint2(s[3]); \
		__asm ( \
	     "s_nop 1\n" \
		  "v_mov_b32_dpp  %[ds1x], %[s1x] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds1y], %[s1y] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds2x], %[s2x] quad_perm:[2,3,0,1]\n" \
        "v_mov_b32_dpp  %[ds2y], %[s2y] quad_perm:[2,3,0,1]\n" \
        "v_mov_b32_dpp  %[ds3x], %[s3x] quad_perm:[1,2,3,0]\n" \
        "v_mov_b32_dpp  %[ds3y], %[s3y] quad_perm:[1,2,3,0]\n" \
		  "s_nop 1\n" \
		  : [ds1x] "=&v" (s1.x), \
          [ds1y] "=&v" (s1.y), \
		    [ds2x] "=&v" (s2.x), \
          [ds2y] "=&v" (s2.y), \
          [ds3x] "=&v" (s3.x), \
          [ds3y] "=&v" (s3.y) \
		  : [s1x] "0" (s1.x), \
          [s1y] "1" (s1.y), \
		    [s2x] "2" (s2.x), \
          [s2y] "3" (s2.y), \
          [s3x] "4" (s3.x), \
          [s3y] "5" (s3.y)); \
        s[1] = as_ulong(s1); \
        s[2] = as_ulong(s2); \
        s[3] = as_ulong(s3); \
	}

#define SHUFFLE_D_0(Data, s) \
    { \
      uint2 s0, s1, s2; \
      s0 = as_uint2(s[0]); \
      s1 = as_uint2(s[1]); \
      s2 = as_uint2(s[2]); \
		__asm ( \
	     "s_nop 1\n" \
		  "v_mov_b32_dpp  %[ds0x], %[s0x] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds0y], %[s0y] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds1x], %[s1x] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds1y], %[s1y] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds2x], %[s2x] quad_perm:[3,0,1,2]\n" \
        "v_mov_b32_dpp  %[ds2y], %[s2y] quad_perm:[3,0,1,2]\n" \
		  "s_nop 1\n" \
		  : [ds0x] "=&v" (s0.x), \
          [ds0y] "=&v" (s0.y), \
		    [ds1x] "=&v" (s1.x), \
          [ds1y] "=&v" (s1.y), \
          [ds2x] "=&v" (s2.x), \
          [ds2y] "=&v" (s2.y) \
		  : [s0x] "0" (s0.x), \
          [s0y] "1" (s0.y), \
		    [s1x] "2" (s1.x), \
          [s1y] "3" (s1.y), \
          [s2x] "4" (s2.x), \
          [s2y] "5" (s2.y)); \
      Data ## 0 = as_ulong(s0); \
      Data ## 1 = as_ulong(s1); \
      Data ## 2 = as_ulong(s2); \
	}

#define BROADCAST_0(d, s)  \
    { \
		__asm ( \
	     "s_nop 1\n" \
		  "v_mov_b32_dpp  %[d0], %[s0] quad_perm:[0,0,0,0]\n" \
		  "s_nop 1\n" \
		  : [d0] "=&v" (d) \
		  : [s0] "0" (s)); \
	}

#define BROADCAST_L_0(d, l, s)  \
    { \
		__asm ( \
		  "ds_bpermute_b32  %[d0], %[l0], %[s0]\n" \
		  "s_waitcnt lgkmcnt(0)\n" \
		  : [d0] "=&v" (d) \
		  : [l0] "v" (l), \
          [s0] "v" (s)); \
	}

#define roundLyra_sm(state) \
{ \
    Gfunc(state[0], state[1], state[2], state[3]); \
    SHUFFLE_0(state); \
 \
    Gfunc(state[0], state[1], state[2], state[3]); \
 \
    SHUFFLE_1(state); \
}

#define roundLyra_sm_ext(state) \
{ \
    Gfunc(state[0], state[1], state[2], state[3]); \
    SHUFFLE_0(state); \
 \
    Gfunc(state[0], state[1], state[2], state[3]); \
 \
    SHUFFLE_1(state); \
}

struct SharedState
{
    ulong s[4];
};

#define loop3p1_iteration(st00,st01,st02, lm20,lm21,lm22) \
{ \
    t0 = state0[st00]; \
    c0 = state1[st00] + t0; \
    state[0] ^= c0; \
 \
    t0 = state0[st01]; \
    c0 = state1[st01] + t0; \
    state[1] ^= c0; \
 \
    t0 = state0[st02]; \
    c0 = state1[st02] + t0; \
    state[2] ^= c0; \
 \
    roundLyra_sm_ext(state); \
 \
    state2[0] = state1[st00]; \
    state2[1] = state1[st01]; \
    state2[2] = state1[st02]; \
 \
    state2[0] ^= state[0]; \
    state2[1] ^= state[1]; \
    state2[2] ^= state[2]; \
 \
    lMatrix[lm20] = state2[0]; \
    lMatrix[lm21] = state2[1]; \
    lMatrix[lm22] = state2[2]; \
 \
    ulong Data0, Data1, Data2; \
    SHUFFLE_D_0(Data, state); \
    if((lIdx&3) == 0) \
    { \
        state0[st01] ^= Data0; \
        state0[st02] ^= Data1; \
        state0[st00] ^= Data2; \
    } \
    else \
    { \
        state0[st00] ^= Data0; \
        state0[st01] ^= Data1; \
        state0[st02] ^= Data2; \
    } \
 \
    lMatrix[st00] = state0[st00]; \
    lMatrix[st01] = state0[st01]; \
    lMatrix[st02] = state0[st02]; \
 \
    state0[st00] = state2[0]; \
    state0[st01] = state2[1]; \
    state0[st02] = state2[2]; \
}

#define loop3p2_iteration(st00,st01,st02, st10,st11,st12, lm30,lm31,lm32, lm10,lm11,lm12) \
{ \
    t0 = state1[st00]; \
    c0 = state0[st10] + t0; \
    state[0] ^= c0; \
 \
    t0 = state1[st01]; \
    c0 = state0[st11] + t0; \
    state[1] ^= c0; \
 \
    t0 = state1[st02]; \
    c0 = state0[st12] + t0; \
    state[2] ^= c0; \
 \
    roundLyra_sm_ext(state); \
 \
    state0[st10] ^= state[0]; \
    state0[st11] ^= state[1]; \
    state0[st12] ^= state[2]; \
 \
    lMatrix[lm30] = state0[st10]; \
    lMatrix[lm31] = state0[st11]; \
    lMatrix[lm32] = state0[st12]; \
 \
    ulong Data0, Data1, Data2; \
    SHUFFLE_D_0(Data, state); \
    if((lIdx&3) == 0) \
    { \
        state1[st01] ^= Data0; \
        state1[st02] ^= Data1; \
        state1[st00] ^= Data2; \
    } \
    else \
    { \
        state1[st00] ^= Data0; \
        state1[st01] ^= Data1; \
        state1[st02] ^= Data2; \
    } \
 \
    lMatrix[lm10] = state1[st00]; \
    lMatrix[lm11] = state1[st01]; \
    lMatrix[lm12] = state1[st02]; \
}

#define wanderIteration(prv00,prv01,prv02, rng00,rng01,rng02, rng10,rng11,rng12, rng20,rng21,rng22, rng30,rng31,rng32, rou00,rou01,rou02) \
{ \
    a_state1_0 = lMatrix[prv00]; \
    a_state1_1 = lMatrix[prv01]; \
    a_state1_2 = lMatrix[prv02]; \
 \
    b0 = (rowa < 2)? lMatrix[rng00]: lMatrix[rng20]; \
    b1 = (rowa < 2)? lMatrix[rng10]: lMatrix[rng30]; \
    a_state2_0 = ((rowa & 0x1U) < 1)? b0: b1; \
 \
    b0 = (rowa < 2)? lMatrix[rng01]: lMatrix[rng21]; \
    b1 = (rowa < 2)? lMatrix[rng11]: lMatrix[rng31]; \
    a_state2_1 = ((rowa & 0x1U) < 1)? b0: b1; \
 \
    b0 = (rowa < 2)? lMatrix[rng02]: lMatrix[rng22]; \
    b1 = (rowa < 2)? lMatrix[rng12]: lMatrix[rng32]; \
    a_state2_2 = ((rowa & 0x1U) < 1)? b0: b1; \
 \
    t0 = a_state1_0; \
    c0 = a_state2_0 + t0; \
    state[0] ^= c0; \
 \
    t0 = a_state1_1; \
    c0 = a_state2_1 + t0; \
    state[1] ^= c0; \
 \
    t0 = a_state1_2; \
    c0 = a_state2_2 + t0; \
    state[2] ^= c0; \
 \
    roundLyra_sm_ext(state); \
    SHUFFLE_D_0(a_state1_, state); \
 \
    if(rowa == 0) \
    { \
        lMatrix[rng00] = a_state2_0; \
        lMatrix[rng01] = a_state2_1; \
        lMatrix[rng02] = a_state2_2; \
        lMatrix[rng00] ^= ((lIdx&3) == 0)?a_state1_2:a_state1_0; \
        lMatrix[rng01] ^= ((lIdx&3) == 0)?a_state1_0:a_state1_1; \
        lMatrix[rng02] ^= ((lIdx&3) == 0)?a_state1_1:a_state1_2; \
    } \
    if(rowa == 1) \
    { \
        lMatrix[rng10] = a_state2_0; \
        lMatrix[rng11] = a_state2_1; \
        lMatrix[rng12] = a_state2_2; \
        lMatrix[rng10] ^= ((lIdx&3) == 0)?a_state1_2:a_state1_0; \
        lMatrix[rng11] ^= ((lIdx&3) == 0)?a_state1_0:a_state1_1; \
        lMatrix[rng12] ^= ((lIdx&3) == 0)?a_state1_1:a_state1_2; \
    } \
    if(rowa == 2) \
    { \
        lMatrix[rng20] = a_state2_0; \
        lMatrix[rng21] = a_state2_1; \
        lMatrix[rng22] = a_state2_2; \
        lMatrix[rng20] ^= ((lIdx&3) == 0)?a_state1_2:a_state1_0; \
        lMatrix[rng21] ^= ((lIdx&3) == 0)?a_state1_0:a_state1_1; \
        lMatrix[rng22] ^= ((lIdx&3) == 0)?a_state1_1:a_state1_2; \
    } \
    if(rowa == 3) \
    { \
        lMatrix[rng30] = a_state2_0; \
        lMatrix[rng31] = a_state2_1; \
        lMatrix[rng32] = a_state2_2; \
        lMatrix[rng30] ^= ((lIdx&3) == 0)?a_state1_2:a_state1_0; \
        lMatrix[rng31] ^= ((lIdx&3) == 0)?a_state1_0:a_state1_1; \
        lMatrix[rng32] ^= ((lIdx&3) == 0)?a_state1_1:a_state1_2; \
    } \
 \
    lMatrix[rou00] ^= state[0]; \
    lMatrix[rou01] ^= state[1]; \
    lMatrix[rou02] ^= state[2]; \
}


#define wanderIterationP2(rin00,rin01,rin02, rng00,rng01,rng02, rng10,rng11,rng12, rng20,rng21,rng22, rng30,rng31,rng32) \
{ \
    t0 = lMatrix[rin00]; \
    b0 = (rowa < 2)? lMatrix[rng00]: lMatrix[rng20]; \
    b1 = (rowa < 2)? lMatrix[rng10]: lMatrix[rng30]; \
    c0 = ((rowa & 0x1U) < 1)? b0: b1; \
    t0 += c0; \
    state[0] ^= t0; \
 \
    t0 = lMatrix[rin01]; \
    b0 = (rowa < 2)? lMatrix[rng01]: lMatrix[rng21]; \
    b1 = (rowa < 2)? lMatrix[rng11]: lMatrix[rng31]; \
    c0 = ((rowa & 0x1U) < 1)? b0: b1; \
    t0 += c0; \
    state[1] ^= t0; \
 \
    t0 = lMatrix[rin02]; \
    b0 = (rowa < 2)? lMatrix[rng02]: lMatrix[rng22]; \
    b1 = (rowa < 2)? lMatrix[rng12]: lMatrix[rng32]; \
    c0 = ((rowa & 0x1U) < 1)? b0: b1; \
    t0 += c0; \
    state[2] ^= t0; \
 \
    roundLyra_sm(state); \
}


typedef union
{
    uint h[32];
    ulong h2[16];
    uint4 h4[8];
    ulong4 h8[4];
} LyraState;

// lyra2v3 p2
__attribute__((reqd_work_group_size(64, 1, 1)))
__kernel void lyra441p2(__global uint* lyraStates)
{
    int gid = (get_global_id(0) >> 2);
    __global LyraState *lyraState = (__global LyraState *)(lyraStates + (32* (gid)));

    ulong state[4];
    ulong ttr;
    
    uint lIdx = (uint)get_local_id(0);
    uint gr4 = ((lIdx >> 2) << 2);
    
    //-------------------------------------
    // Load Lyra state
    state[0] = (ulong)(lyraState->h2[(lIdx & 3)]);
    state[1] = (ulong)(lyraState->h2[(lIdx & 3)+4]);
    state[2] = (ulong)(lyraState->h2[(lIdx & 3)+8]);
    state[3] = (ulong)(lyraState->h2[(lIdx & 3)+12]);

    //-------------------------------------
    ulong lMatrix[48];
    ulong state0[12];
    ulong state1[12];
    
    //------------------------------------
    // loop 1
    {
        state0[ 9] = state[0];
        state0[10] = state[1];
        state0[11] = state[2];
        
        roundLyra_sm(state);

        state0[6] = state[0];
        state0[7] = state[1];
        state0[8] = state[2];
        
        roundLyra_sm(state);
        
        state0[3] = state[0];
        state0[4] = state[1];
        state0[5] = state[2];
        
        roundLyra_sm(state);
        
        state0[0] = state[0];
        state0[1] = state[1];
        state0[2] = state[2];
        
        roundLyra_sm(state);
    }
    
    //------------------------------------
    // loop 2
    {
        state[0] ^= state0[0];
        state[1] ^= state0[1];
        state[2] ^= state0[2];
        roundLyra_sm(state);
        state1[ 9] = state0[0] ^ state[0];
        state1[10] = state0[1] ^ state[1];
        state1[11] = state0[2] ^ state[2];
        
        state[0] ^= state0[3];
        state[1] ^= state0[4];
        state[2] ^= state0[5];
        roundLyra_sm(state);
        state1[6] = state0[3] ^ state[0];
        state1[7] = state0[4] ^ state[1];
        state1[8] = state0[5] ^ state[2];
        
        state[0] ^= state0[6];
        state[1] ^= state0[7];
        state[2] ^= state0[8];
        roundLyra_sm(state);
        state1[3] = state0[6] ^ state[0];
        state1[4] = state0[7] ^ state[1];
        state1[5] = state0[8] ^ state[2];
        
        state[0] ^= state0[ 9];
        state[1] ^= state0[10];
        state[2] ^= state0[11];
        roundLyra_sm(state);
        state1[0] = state0[ 9] ^ state[0];
        state1[1] = state0[10] ^ state[1];
        state1[2] = state0[11] ^ state[2];
    }

    ulong state2[3];
    ulong t0,c0;
    loop3p1_iteration(0, 1, 2, 33,34,35);
    loop3p1_iteration(3, 4, 5, 30,31,32);
    loop3p1_iteration(6, 7, 8, 27,28,29);
    loop3p1_iteration(9,10,11, 24,25,26);

    loop3p2_iteration(0, 1, 2, 9,10,11, 45,46,47, 12,13,14);
    loop3p2_iteration(3, 4, 5, 6, 7, 8, 42,43,44, 15,16,17);
    loop3p2_iteration(6, 7, 8, 3, 4, 5, 39,40,41, 18,19,20);
    loop3p2_iteration(9,10,11, 0, 1, 2, 36,37,38, 21,22,23);
 
    ulong a_state1_0, a_state1_1, a_state1_2;
    ulong a_state2_0, a_state2_1, a_state2_2;
    ulong b0,b1;

    //------------------------------------
    // Wandering phase part 1
    uint rowa, index, sid, lid;
    BROADCAST_0(index, ((uint) state[0]));
    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(rowa, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(rowa, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(rowa, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(rowa, lid, ((uint) state[3]));
    rowa &= 0x3;

    wanderIteration(36,37,38, 0, 1, 2, 12,13,14, 24,25,26, 36,37,38, 0, 1, 2);
    wanderIteration(39,40,41, 3, 4, 5, 15,16,17, 27,28,29, 39,40,41, 3, 4, 5);
    wanderIteration(42,43,44, 6, 7, 8, 18,19,20, 30,31,32, 42,43,44, 6, 7, 8);
    wanderIteration(45,46,47, 9,10,11, 21,22,23, 33,34,35, 45,46,47, 9,10,11);

    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(index, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(index, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(index, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(index, lid, ((uint) state[3]));
    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(rowa, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(rowa, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(rowa, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(rowa, lid, ((uint) state[3]));
    rowa &= 0x3;
    
    wanderIteration(0, 1, 2, 0, 1, 2, 12,13,14, 24,25,26, 36,37,38, 12,13,14);
    wanderIteration(3, 4, 5, 3, 4, 5, 15,16,17, 27,28,29, 39,40,41, 15,16,17);
    wanderIteration(6, 7, 8, 6, 7, 8, 18,19,20, 30,31,32, 42,43,44, 18,19,20);
    wanderIteration(9,10,11, 9,10,11, 21,22,23, 33,34,35, 45,46,47, 21,22,23);

    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(index, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(index, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(index, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(index, lid, ((uint) state[3]));
    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(rowa, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(rowa, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(rowa, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(rowa, lid, ((uint) state[3]));
    rowa &= 0x3;
    
    wanderIteration(12,13,14, 0, 1, 2, 12,13,14, 24,25,26, 36,37,38, 24,25,26);
    wanderIteration(15,16,17, 3, 4, 5, 15,16,17, 27,28,29, 39,40,41, 27,28,29);
    wanderIteration(18,19,20, 6, 7, 8, 18,19,20, 30,31,32, 42,43,44, 30,31,32);
    wanderIteration(21,22,23, 9,10,11, 21,22,23, 33,34,35, 45,46,47, 33,34,35);

    //------------------------------------
    // Wandering phase part 2 (last iteration)
    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(index, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(index, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(index, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(index, lid, ((uint) state[3]));
    sid = ((index >> 2) & 0x3);
    lid = ((gr4 + (index & 3)) << 2);
    if (sid == 0) BROADCAST_L_0(rowa, lid, ((uint) state[0]));
    if (sid == 1) BROADCAST_L_0(rowa, lid, ((uint) state[1]));
    if (sid == 2) BROADCAST_L_0(rowa, lid, ((uint) state[2]));
    if (sid == 3) BROADCAST_L_0(rowa, lid, ((uint) state[3]));
    rowa &= 0x3;

    ulong last[3];

    b0 = (rowa < 2)? lMatrix[0]: lMatrix[24];
    b1 = (rowa < 2)? lMatrix[12]: lMatrix[36];
    last[0] = ((rowa & 0x1U) < 1)? b0: b1;

    b0 = (rowa < 2)? lMatrix[1]: lMatrix[25];
    b1 = (rowa < 2)? lMatrix[13]: lMatrix[37];
    last[1] = ((rowa & 0x1U) < 1)? b0: b1;

    b0 = (rowa < 2)? lMatrix[2]: lMatrix[26];
    b1 = (rowa < 2)? lMatrix[14]: lMatrix[38];
    last[2] = ((rowa & 0x1U) < 1)? b0: b1;


    t0 = lMatrix[24];
    c0 = last[0] + t0;
    state[0] ^= c0;
    
    t0 = lMatrix[25];
    c0 = last[1] + t0;
    state[1] ^= c0;
    
    t0 = lMatrix[26];
    c0 = last[2] + t0;
    state[2] ^= c0;

    roundLyra_sm_ext(state);
   
    ulong Data0, Data1, Data2;
    SHUFFLE_D_0(Data, state);
    if((lIdx&3) == 0)
    {
        last[1] ^= Data0;
        last[2] ^= Data1;
        last[0] ^= Data2;
    }
    else
    {
        last[0] ^= Data0;
        last[1] ^= Data1;
        last[2] ^= Data2;
    }

    if(rowa == 3)
    {
        last[0] ^= state[0];
        last[1] ^= state[1];
        last[2] ^= state[2];
    }

    wanderIterationP2(27,28,29, 3, 4, 5, 15,16,17, 27,28,29, 39,40,41);
    wanderIterationP2(30,31,32, 6, 7, 8, 18,19,20, 30,31,32, 42,43,44);
    wanderIterationP2(33,34,35, 9,10,11, 21,22,23, 33,34,35, 45,46,47);

    state[0] ^= last[0];
    state[1] ^= last[1];
    state[2] ^= last[2];

    //-------------------------------------
    // save lyra state    
    lyraState->h2[(lIdx & 3)] = state[0];
    lyraState->h2[(lIdx & 3)+4] = state[1];
    lyraState->h2[(lIdx & 3)+8] = state[2];
    lyraState->h2[(lIdx & 3)+12] = state[3];
    
    barrier(CLK_GLOBAL_MEM_FENCE);
}