/*
 * Copyright 2018-2019 CryptoGraphics <CrGr@protonmail.com>.
 * Copyright 2020 fancyIX
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version. See LICENSE for more details.
 */

#define SWAP4(x) as_uint(as_uchar4(x).wzyx)
#define SWAP8(x) as_ulong(as_uchar8(x).s76543210)
#define SWAP32(x) as_ulong(as_uint2(x).s10)

#define rotr64(x, n) ((n) < 32 ? (amd_bitalign((uint)((x) >> 32), (uint)(x), (uint)(n)) | ((ulong)amd_bitalign((uint)(x), (uint)((x) >> 32), (uint)(n)) << 32)) : (amd_bitalign((uint)(x), (uint)((x) >> 32), (uint)(n) - 32) | ((ulong)amd_bitalign((uint)((x) >> 32), (uint)(x), (uint)(n) - 32) << 32)))

#define Gfunc(a,b,c,d) \
{ \
    a += b;  \
    d ^= a; \
    ttr = rotr64(d, 32); \
    d = ttr; \
 \
    c += d;  \
    b ^= c; \
    ttr = rotr64(b, 24); \
    b = ttr; \
 \
    a += b;  \
    d ^= a; \
    ttr = rotr64(d, 16); \
    d = ttr; \
 \
    c += d; \
    b ^= c; \
    ttr = rotr64(b, 63); \
    b = ttr; \
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


#if defined(__GCNMINC__)
uint2 __attribute__((overloadable)) amd_bitalign(uint2 src0, uint2 src1, uint src2)
{
	uint dstx = 0;
	uint dsty = 0;
    __asm ("v_alignbit_b32 %[dstx], %[src0x], %[src1x], %[src2x]\n"
          "v_alignbit_b32 %[dsty], %[src0y], %[src1y], %[src2y]"
          : [dstx] "=&v" (dstx), [dsty] "=&v" (dsty)
          : [src0x] "v" (src0.x), [src1x] "v" (src1.x), [src2x] "v" (src2),
		    [src0y] "v" (src0.y), [src1y] "v" (src1.y), [src2y] "v" (src2));
	return (uint2) (dstx, dsty);
}
uint2 __attribute__((overloadable)) amd_bytealign(uint2 src0, uint2 src1, uint src2)
{
	uint dstx = 0;
	uint dsty = 0;
    __asm ("v_alignbyte_b32 %[dstx], %[src0x], %[src1x], %[src2x]\n"
          "v_alignbyte_b32 %[dsty], %[src0y], %[src1y], %[src2y]"
          : [dstx] "=&v" (dstx), [dsty] "=&v" (dsty)
          : [src0x] "v" (src0.x), [src1x] "v" (src1.x), [src2x] "v" (src2),
		    [src0y] "v" (src0.y), [src1y] "v" (src1.y), [src2y] "v" (src2));
	return (uint2) (dstx, dsty);
}
#else
#pragma OPENCL EXTENSION cl_amd_media_ops : enable
#pragma OPENCL EXTENSION cl_amd_media_ops2 : enable
#endif

#define ROTR64(x2, y) as_ulong(y < 32 ? (y % 8 == 0 ? (((amd_bytealign(x2.s10, x2, y / 8)))) : (((amd_bitalign(x2.s10, x2, y))))) : (((amd_bitalign(x2, x2.s10, (y - 32))))))
#define ROTR64_24(x2) as_ulong(amd_bytealign(x2.s10, x2, 3))
#define ROTR64_16(x2) as_ulong(amd_bytealign(x2.s10, x2, 2))
#define ROTR64_63(x2) as_ulong(amd_bitalign(x2, x2.s10, 31))

/// lyra2 algo  ///////////////////////////////////////////////////////////
#define HASH_SIZE (256 / 8) // size in bytes of an hash in/out
#define SLOT (get_global_id(1))
#define LOCAL_LINEAR (get_local_id(0) & 3)
#define REG_ROW_COUNT (1) // ideally all happen at the same clock
#define STATE_BLOCK_COUNT (1 * REG_ROW_COUNT)  // very close instructions
#define LYRA_ROUNDS 8
#define HYPERMATRIX_COUNT (LYRA_ROUNDS * STATE_BLOCK_COUNT)

#define ADD32_DPP(a, b) \
    __asm ( \
	    "v_add_co_u32  %[aa], vcc_lo, %[bb], %[aa]\n" \
		"s_lshl_b32 vcc_lo, vcc_lo, 1\n" \
		"s_and_b32 vcc_lo, vcc_lo, 0xAAAAAAAA\n" \
		"v_add_co_ci_u32 %[daa], vcc_lo, 0, %[aa], vcc_lo\n" \
		: [daa] "=v" (a) \
		: [aa] "0" (a), \
		  [bb] "v" (b) \
		: "vcc");

#define SWAP32_DPP(s) \
    ss = s; \
	{ \
		__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[p], %[pp] quad_perm:[1,0,3,2]\n" \
		  "s_nop 1" \
		  : [p] "=v" (s) \
		  : [pp] "v" (ss)); \
	}

#define ROTR64_24_DPP(s) \
    ss = s; \
	{ \
		__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dpp], %[pp] quad_perm:[1,0,3,2]\n" \
		  "s_nop 1\n" \
		  "v_alignbyte_b32 %[dp], %[dpp], %[p], 3" \
		  : [dpp] "=v" (ss), \
		    [dp] "=v" (s) \
		  : [pp] "0" (ss), \
		    [p] "1" (s)); \
	}

#define ROTR64_16_DPP(s) \
    ss = s; \
	{ \
		__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dpp], %[pp] quad_perm:[1,0,3,2]\n" \
		  "s_nop 1\n" \
		  "v_alignbyte_b32 %[dp], %[dpp], %[p], 2" \
		  : [dpp] "=v" (ss), \
		    [dp] "=v" (s) \
		  : [pp] "0" (ss), \
		    [p] "1" (s)); \
	}

#define ROTR64_63_DPP(s) \
    ss = s; \
	{ \
		__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dpp], %[pp] quad_perm:[1,0,3,2]\n" \
		  "s_nop 1\n" \
		  "v_alignbit_b32 %[dp], %[p], %[dpp], 31" \
		  : [dpp] "=v" (ss), \
		    [dp] "=v" (s) \
		  : [pp] "0" (ss), \
		    [p] "1" (s)); \
	}

// Usually just #define G(a,b,c,d)...; I have no time to read the Lyra paper
// but that looks like some kind of block cipher I guess.
#define cipher_G_macro(s) \
    ADD32_DPP(s[0], s[1]); s[3] ^= s[0]; SWAP32_DPP(s[3]); \
    ADD32_DPP(s[2], s[3]); s[1] ^= s[2]; ROTR64_24_DPP(s[1]); \
    ADD32_DPP(s[0], s[1]); s[3] ^= s[0]; ROTR64_16_DPP(s[3]); \
    ADD32_DPP(s[2], s[3]); s[1] ^= s[2]; ROTR64_63_DPP(s[1]);

#define shflldpp(state) \
	__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dp10], %[p10] row_ror:12\n" \
		  "v_mov_b32_dpp  %[dp20], %[p20] row_ror:8\n" \
		  "v_mov_b32_dpp  %[dp30], %[p30] row_ror:4\n" \
		  "s_nop 1" \
		  : [dp10] "=v" (state[1]), \
			[dp20] "=v" (state[2]), \
			[dp30] "=v" (state[3]) \
		  : [p10] "0" (state[1]), \
			[p20] "1" (state[2]), \
			[p30] "2" (state[3]));

#define shflrdpp(state) \
	__asm ( \
	      "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dp10], %[p10] row_ror:4\n" \
		  "v_mov_b32_dpp  %[dp20], %[p20] row_ror:8\n" \
		  "v_mov_b32_dpp  %[dp30], %[p30] row_ror:12\n" \
		  "s_nop 1" \
		  : [dp10] "=v" (state[1]), \
			[dp20] "=v" (state[2]), \
			[dp30] "=v" (state[3]) \
		  : [p10] "0" (state[1]), \
			[p20] "1" (state[2]), \
			[p30] "2" (state[3]));

// pad counts 4 entries each hash team of 4
#define round_lyra_4way_sw(state)   \
	cipher_G_macro(state); \
	shflldpp(state); \
	cipher_G_macro(state);\
	shflrdpp(state);

#define xorrot_one_dpp(sII, state) \
	s0 = state[0]; \
	s1 = state[1]; \
	s2 = state[2]; \
	__asm ( \
		  "s_nop 1\n" \
		  "v_mov_b32_dpp  %[dp10], %[p10] row_ror:4\n" \
		  "v_mov_b32_dpp  %[dp20], %[p20] row_ror:4\n" \
		  "v_mov_b32_dpp  %[dp30], %[p30] row_ror:4\n" \
		  "s_nop 1" \
		  : [dp10] "=v" (s0), \
			[dp20] "=v" (s1), \
			[dp30] "=v" (s2) \
		  : [p10] "0" (s0), \
			[p20] "1" (s1), \
			[p30] "2" (s2)); \
	if ((get_local_id(1) & 3) == 1) sII[0] ^= (s0); \
	if ((get_local_id(1) & 3) == 1) sII[1] ^= (s1); \
	if ((get_local_id(1) & 3) == 1) sII[2] ^= (s2); \
	if ((get_local_id(1) & 3) == 2) sII[0] ^= (s0); \
	if ((get_local_id(1) & 3) == 2) sII[1] ^= (s1); \
	if ((get_local_id(1) & 3) == 2) sII[2] ^= (s2); \
	if ((get_local_id(1) & 3) == 3) sII[0] ^= (s0); \
	if ((get_local_id(1) & 3) == 3) sII[1] ^= (s1); \
	if ((get_local_id(1) & 3) == 3) sII[2] ^= (s2); \
	if ((get_local_id(1) & 3) == 0) sII[0] ^= (s2); \
	if ((get_local_id(1) & 3) == 0) sII[1] ^= (s0); \
	if ((get_local_id(1) & 3) == 0) sII[2] ^= (s1); \

#define write_state(notepad, state, row, col) \
  notepad[24 * row + col * 3] = state[0]; \
  notepad[24 * row + col * 3 + 1] = state[1]; \
  notepad[24 * row + col * 3 + 2] = state[2];

#define state_xor_modify(modify, row, col, mindex, state, notepad) \
  if (modify == row) state[0] ^= notepad[24 * row + col * 3]; \
  if (modify == row) state[1] ^= notepad[24 * row + col * 3 + 1]; \
  if (modify == row) state[2] ^= notepad[24 * row + col * 3 + 2];

#define state_xor(state, bigMat, mindex, row, col) \
  si[0] = bigMat[24 * row + col * 3]; state[0] ^= bigMat[24 * row + col * 3]; \
  si[1] = bigMat[24 * row + col * 3 + 1]; state[1] ^= bigMat[24 * row + col * 3 + 1]; \
  si[2] = bigMat[24 * row + col * 3 + 2]; state[2] ^= bigMat[24 * row + col * 3 + 2];

#define xor_state(state, bigMat, mindex, row, col) \
  si[0] ^= state[0]; bigMat[24 * row + col * 3] = si[0]; \
  si[1] ^= state[1]; bigMat[24 * row + col * 3 + 1] = si[1]; \
  si[2] ^= state[2]; bigMat[24 * row + col * 3 + 2] = si[2];

#define state_xor_plus(state, bigMat, mindex, matin, colin, matrw, colrw) \
   si[0] = bigMat[24 * matin + colin * 3]; sII[0] = bigMat[24 * matrw + colrw * 3]; ss = si[0]; ADD32_DPP(ss, sII[0]); state[0] ^= ss; \
   si[1] = bigMat[24 * matin + colin * 3 + 1]; sII[1] = bigMat[24 * matrw + colrw * 3 + 1]; ss = si[1]; ADD32_DPP(ss, sII[1]); state[1] ^= ss; \
   si[2] = bigMat[24 * matin + colin * 3 + 2]; sII[2] = bigMat[24 * matrw + colrw * 3 + 2]; ss = si[2]; ADD32_DPP(ss, sII[2]); state[2] ^= ss;

#define make_hyper_one_macro(state, bigMat) do { \
    { \
		state_xor(state, bigMat, mindex, 0, 0); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 7); \
		state_xor(state, bigMat, mindex, 0, 1); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 6); \
		state_xor(state, bigMat, mindex, 0, 2); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 5); \
		state_xor(state, bigMat, mindex, 0, 3); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 4); \
		state_xor(state, bigMat, mindex, 0, 4); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 3); \
		state_xor(state, bigMat, mindex, 0, 5); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 2); \
		state_xor(state, bigMat, mindex, 0, 6); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 1); \
		state_xor(state, bigMat, mindex, 0, 7); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, 1, 0); \
	} \
} while (0);

#define make_next_hyper_macro(matin, matrw, matout, state, bigMat) do { \
	{ \
		state_xor_plus(state, bigMat, mindex, matin, 0, matrw, 0); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 7); \
		xorrot_one_dpp(sII, state); \
		write_state(bigMat, sII, matrw, 0); \
		state_xor_plus(state, bigMat, mindex, matin, 1, matrw, 1); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 6); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 1); \
		state_xor_plus(state, bigMat, mindex, matin, 2, matrw, 2); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 5); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 2); \
		state_xor_plus(state, bigMat, mindex, matin, 3, matrw, 3); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 4); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 3); \
		state_xor_plus(state, bigMat, mindex, matin, 4, matrw, 4); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 3); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 4); \
		state_xor_plus(state, bigMat, mindex, matin, 5, matrw, 5); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 2); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 5); \
		state_xor_plus(state, bigMat, mindex, matin, 6, matrw, 6); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 1); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 6); \
		state_xor_plus(state, bigMat, mindex, matin, 7, matrw, 7); \
		round_lyra_4way_sw(state); \
		xor_state(state, bigMat, mindex, matout, 0); \
		xorrot_one_dpp(sII, state); \
        write_state(bigMat, sII, matrw, 7); \
	} \
} while (0);

#define broadcast_zero(s) \
    p0 = (s[0] & 7); \
	p1 = (s[0] & 7); \
	p2 = (s[0] & 7); \
	p3 = (s[0] & 7); \
	__asm ( \
		  "s_nop 0\n" \
		  "v_mov_b32_dpp  %[dp0], %[p0] quad_perm:[0,0,2,2]\n" \
		  "v_mov_b32_dpp  %[p1], %[p1] quad_perm:[0,0,2,2]\n" \
		  "v_mov_b32_dpp  %[p2], %[p2] quad_perm:[0,0,2,2]\n" \
		  "v_mov_b32_dpp  %[p3], %[p3] quad_perm:[0,0,2,2]\n" \
		  "v_mov_b32_dpp  %[dp1], %[p1] row_ror:4\n" \
		  "v_mov_b32_dpp  %[dp2], %[p2] row_ror:8\n" \
		  "v_mov_b32_dpp  %[dp3], %[p3] row_ror:12\n" \
		  "s_nop 0" \
		  : [dp0] "=v" (p0), \
		    [dp1] "=v" (p1), \
		    [dp2] "=v" (p2), \
			[dp3] "=v" (p3) \
		  : [p0] "0" (p0), \
		    [p1] "1" (p1), \
			[p2] "2" (p2), \
			[p3] "3" (p3)); \
	if ((get_local_id(1) & 3) == 1) modify = p1; \
	if ((get_local_id(1) & 3) == 2) modify = p2; \
	if ((get_local_id(1) & 3) == 3) modify = p3; \
	if ((get_local_id(1) & 3) == 0) modify = p0; \

#define real_matrw_read(sII, bigMat, matrw, off) \
		if (matrw == 0) sII[0] = bigMat[24 * 0 + off * 3]; \
		if (matrw == 0) sII[1] = bigMat[24 * 0 + off * 3 + 1]; \
		if (matrw == 0) sII[2] = bigMat[24 * 0 + off * 3 + 2]; \
		if (matrw == 1) sII[0] = bigMat[24 * 1 + off * 3]; \
		if (matrw == 1) sII[1] = bigMat[24 * 1 + off * 3 + 1]; \
		if (matrw == 1) sII[2] = bigMat[24 * 1 + off * 3 + 2]; \
		if (matrw == 2) sII[0] = bigMat[24 * 2 + off * 3]; \
		if (matrw == 2) sII[1] = bigMat[24 * 2 + off * 3 + 1]; \
		if (matrw == 2) sII[2] = bigMat[24 * 2 + off * 3 + 2]; \
		if (matrw == 3) sII[0] = bigMat[24 * 3 + off * 3]; \
		if (matrw == 3) sII[1] = bigMat[24 * 3 + off * 3 + 1]; \
		if (matrw == 3) sII[2] = bigMat[24 * 3 + off * 3 + 2]; \
		if (matrw == 4) sII[0] = bigMat[24 * 4 + off * 3]; \
		if (matrw == 4) sII[1] = bigMat[24 * 4 + off * 3 + 1]; \
		if (matrw == 4) sII[2] = bigMat[24 * 4 + off * 3 + 2]; \
		if (matrw == 5) sII[0] = bigMat[24 * 5 + off * 3]; \
		if (matrw == 5) sII[1] = bigMat[24 * 5 + off * 3 + 1]; \
		if (matrw == 5) sII[2] = bigMat[24 * 5 + off * 3 + 2]; \
		if (matrw == 6) sII[0] = bigMat[24 * 6 + off * 3]; \
		if (matrw == 6) sII[1] = bigMat[24 * 6 + off * 3 + 1]; \
		if (matrw == 6) sII[2] = bigMat[24 * 6 + off * 3 + 2]; \
		if (matrw == 7) sII[0] = bigMat[24 * 7 + off * 3]; \
		if (matrw == 7) sII[1] = bigMat[24 * 7 + off * 3 + 1]; \
		if (matrw == 7) sII[2] = bigMat[24 * 7 + off * 3 + 2];

#define real_matrw_write(sII, bigMat, matrw, off) \
		if (matrw == 0) bigMat[24 * 0 + off * 3] = sII[0]; \
		if (matrw == 0) bigMat[24 * 0 + off * 3 + 1] = sII[1]; \
		if (matrw == 0) bigMat[24 * 0 + off * 3 + 2] = sII[2]; \
		if (matrw == 1) bigMat[24 * 1 + off * 3] = sII[0]; \
		if (matrw == 1) bigMat[24 * 1 + off * 3 + 1] = sII[1]; \
		if (matrw == 1) bigMat[24 * 1 + off * 3 + 2] = sII[2]; \
		if (matrw == 2) bigMat[24 * 2 + off * 3] = sII[0]; \
		if (matrw == 2) bigMat[24 * 2 + off * 3 + 1] = sII[1]; \
		if (matrw == 2) bigMat[24 * 2 + off * 3 + 2] = sII[2]; \
		if (matrw == 3) bigMat[24 * 3 + off * 3] = sII[0]; \
		if (matrw == 3) bigMat[24 * 3 + off * 3 + 1] = sII[1]; \
		if (matrw == 3) bigMat[24 * 3 + off * 3 + 2] = sII[2]; \
		if (matrw == 4) bigMat[24 * 4 + off * 3] = sII[0]; \
		if (matrw == 4) bigMat[24 * 4 + off * 3 + 1] = sII[1]; \
		if (matrw == 4) bigMat[24 * 4 + off * 3 + 2] = sII[2]; \
		if (matrw == 5) bigMat[24 * 5 + off * 3] = sII[0]; \
		if (matrw == 5) bigMat[24 * 5 + off * 3 + 1] = sII[1]; \
		if (matrw == 5) bigMat[24 * 5 + off * 3 + 2] = sII[2]; \
		if (matrw == 6) bigMat[24 * 6 + off * 3] = sII[0]; \
		if (matrw == 6) bigMat[24 * 6 + off * 3 + 1] = sII[1]; \
		if (matrw == 6) bigMat[24 * 6 + off * 3 + 2] = sII[2]; \
		if (matrw == 7) bigMat[24 * 7 + off * 3] = sII[0]; \
		if (matrw == 7) bigMat[24 * 7 + off * 3 + 1] = sII[1]; \
		if (matrw == 7) bigMat[24 * 7 + off * 3 + 2] = sII[2];

#define state_xor_plus_modify(state, bigMat, mindex, matin, colin, matrw, colrw) \
   si[0] = bigMat[24 * matin + colin * 3]; \
   si[1] = bigMat[24 * matin + colin * 3 + 1]; \
   si[2] = bigMat[24 * matin + colin * 3 + 2]; \
   real_matrw_read(sII, bigMat, matrw, colrw); \
   ss = si[0]; ADD32_DPP(ss, sII[0]); state[0] ^= ss; \
   ss = si[1]; ADD32_DPP(ss, sII[1]); state[1] ^= ss; \
   ss = si[2]; ADD32_DPP(ss, sII[2]); state[2] ^= ss;

#define xor_state_modify(state, bigMat, mindex, row, col) \
  bigMat[24 * row + col * 3] ^= state[0]; \
  bigMat[24 * row + col * 3 + 1] ^= state[1]; \
  bigMat[24 * row + col * 3 + 2] ^= state[2];

#define hyper_xor_dpp_macro( matin, matrw, matout, state, bigMat) do { \
    { \
		state_xor_plus_modify(state, bigMat, mindex, matin, 0, matrw, 0); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 0); xor_state_modify(state, bigMat, mindex, matout, 0); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 1, matrw, 1); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 1); xor_state_modify(state, bigMat, mindex, matout, 1); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 2, matrw, 2); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 2); xor_state_modify(state, bigMat, mindex, matout, 2); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 3, matrw, 3); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 3); xor_state_modify(state, bigMat, mindex, matout, 3); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 4, matrw, 4); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 4); xor_state_modify(state, bigMat, mindex, matout, 4); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 5, matrw, 5); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 5); xor_state_modify(state, bigMat, mindex, matout, 5); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 6, matrw, 6); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 6); xor_state_modify(state, bigMat, mindex, matout, 6); \
		state_xor_plus_modify(state, bigMat, mindex, matin, 7, matrw, 7); \
		round_lyra_4way_sw(state); \
		xorrot_one_dpp(sII, state); \
		real_matrw_write(sII, bigMat, matrw, 7); xor_state_modify(state, bigMat, mindex, matout, 7); \
	} \
} while (0);


typedef union {
    uint h4[8];
    ulong h8[4];
    uint4 h16[2];
    ulong2 hl16[2];
    ulong4 h32;
} hash2_t;

typedef union {
    uint h4[32];
    ulong h8[16];
    uint4 h16[8];
    ulong2 hl16[8];
    ulong4 h32[4];
} lyraState_t;

__attribute__((amdgpu_waves_per_eu(1,1)))
__attribute__((amdgpu_num_vgpr(256)))
__attribute__((reqd_work_group_size(4, 4, 16)))
__kernel void lyra888p2(__global uchar* sharedDataBuf)
{
uint gid = get_global_id(2);
  __global lyraState_t *lyraState = (__global lyraState_t *)(sharedDataBuf + ((8 * 4 * 4 * 2) * (gid)));
  __global lyraState_t *lyraState2 = (__global lyraState_t *)(sharedDataBuf + ((8 * 4 * 4) + (8 * 4 * 4 * 2) * (gid)));

  uint notepad[192];

  const int player = get_local_id(1);

  uint state[4];
  uint si[3];
  uint sII[3];
  uint s0;
	uint s1;
	uint s2;
	uint s3;
  int ss0;
  uint ss1;
	uint ss3;
  uint ss;
  uint carry;
  const uint mindex = (LOCAL_LINEAR & 1) == 0 ? 0 : 1;
  //-------------------------------------
  // Load Lyra state
  if (LOCAL_LINEAR == 0) state[0] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 0]));
  if (LOCAL_LINEAR == 0) state[1] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 1]));
  if (LOCAL_LINEAR == 0) state[2] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 2]));
  if (LOCAL_LINEAR == 0) state[3] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 3]));
  if (LOCAL_LINEAR == 1) state[0] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 0 + 1]));
  if (LOCAL_LINEAR == 1) state[1] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 1 + 1]));
  if (LOCAL_LINEAR == 1) state[2] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 2 + 1]));
  if (LOCAL_LINEAR == 1) state[3] = ((uint)(lyraState->h4[2 * player + 2 * 4 * 3 + 1]));
  if (LOCAL_LINEAR == 2) state[0] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 0]));
  if (LOCAL_LINEAR == 2) state[1] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 1]));
  if (LOCAL_LINEAR == 2) state[2] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 2]));
  if (LOCAL_LINEAR == 2) state[3] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 3]));
  if (LOCAL_LINEAR == 3) state[0] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 0 + 1]));
  if (LOCAL_LINEAR == 3) state[1] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 1 + 1]));
  if (LOCAL_LINEAR == 3) state[2] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 2 + 1]));
  if (LOCAL_LINEAR == 3) state[3] = ((uint)(lyraState2->h4[2 * player + 2 * 4 * 3 + 1]));

  write_state(notepad, state, 0, 7);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 6);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 5);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 4);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 3);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 2);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 1);
  round_lyra_4way_sw(state);
  write_state(notepad, state, 0, 0);
  round_lyra_4way_sw(state);
  
  make_hyper_one_macro(state, notepad);
  
  make_next_hyper_macro(1, 0, 2, state, notepad);
  make_next_hyper_macro(2, 1, 3, state, notepad);
  make_next_hyper_macro(3, 0, 4, state, notepad);
  make_next_hyper_macro(4, 3, 5, state, notepad);
  make_next_hyper_macro(5, 2, 6, state, notepad);
  make_next_hyper_macro(6, 1, 7, state, notepad);
  
  uint modify = 0;
  uint p0;
  uint p1;
  uint p2;
  uint p3;

  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 1, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(1, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 0, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(0, modify, 7, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(7, modify, 6, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(6, modify, 5, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(5, modify, 4, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(4, modify, 3, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(3, modify, 2, state, notepad);
  broadcast_zero(state);
  hyper_xor_dpp_macro(2, modify, 1, state, notepad);

  state_xor_modify(modify, 0, 0, mindex, state, notepad);
  state_xor_modify(modify, 1, 0, mindex, state, notepad);
  state_xor_modify(modify, 2, 0, mindex, state, notepad);
  state_xor_modify(modify, 3, 0, mindex, state, notepad);
  state_xor_modify(modify, 4, 0, mindex, state, notepad);
  state_xor_modify(modify, 5, 0, mindex, state, notepad);
  state_xor_modify(modify, 6, 0, mindex, state, notepad);
  state_xor_modify(modify, 7, 0, mindex, state, notepad);

//-------------------------------------
  // save lyra state
  if (LOCAL_LINEAR == 0) lyraState->h4[2 * player + 2 * 4 * 0] = state[0];
  if (LOCAL_LINEAR == 0) lyraState->h4[2 * player + 2 * 4 * 1] = state[1];
  if (LOCAL_LINEAR == 0) lyraState->h4[2 * player + 2 * 4 * 2] = state[2];
  if (LOCAL_LINEAR == 0) lyraState->h4[2 * player + 2 * 4 * 3] = state[3];
  if (LOCAL_LINEAR == 2) lyraState2->h4[2 * player + 2 * 4 * 0] = state[0];
  if (LOCAL_LINEAR == 2) lyraState2->h4[2 * player + 2 * 4 * 1] = state[1];
  if (LOCAL_LINEAR == 2) lyraState2->h4[2 * player + 2 * 4 * 2] = state[2];
  if (LOCAL_LINEAR == 2) lyraState2->h4[2 * player + 2 * 4 * 3] = state[3];
  if (LOCAL_LINEAR == 1) lyraState->h4[2 * player + 2 * 4 * 0 + 1] = state[0];
  if (LOCAL_LINEAR == 1) lyraState->h4[2 * player + 2 * 4 * 1 + 1] = state[1];
  if (LOCAL_LINEAR == 1) lyraState->h4[2 * player + 2 * 4 * 2 + 1] = state[2];
  if (LOCAL_LINEAR == 1) lyraState->h4[2 * player + 2 * 4 * 3 + 1] = state[3];
  if (LOCAL_LINEAR == 3) lyraState2->h4[2 * player + 2 * 4 * 0 + 1] = state[0];
  if (LOCAL_LINEAR == 3) lyraState2->h4[2 * player + 2 * 4 * 1 + 1] = state[1];
  if (LOCAL_LINEAR == 3) lyraState2->h4[2 * player + 2 * 4 * 2 + 1] = state[2];
  if (LOCAL_LINEAR == 3) lyraState2->h4[2 * player + 2 * 4 * 3 + 1] = state[3];

  barrier(CLK_GLOBAL_MEM_FENCE);
}