#!/usr/bin/env python3
"""
FP16-Accurate Golden Model for AttentionCore-SOC.
Mimics the hardware pipeline EXACTLY using integer bit-level FP16 operations:
  - fp16_mul: truncation (no rounding), matching fp16_multiplier.sv
  - fp16_add: truncation (no rounding), matching fp16_adder.sv
  - fp16_exp_lut: 256-entry LUT indexed by {exp[4:0], man[9:7]}
  - fp16_reciprocal: 64-entry LUT indexed by man[9:4]
  - fp16_max: binary tree comparator, tie goes to a
  - fp16_rowsum: binary tree adder (same tree structure as fp16_rowsum.sv)
  - S = Q @ K^T (sequential MAC accumulation, 8 elements)
  - S_scaled = S * scale (fp16_mul)
  - Softmax: rowmax (tree), subtraction (fp16_sub), exp_lut, rowsum (tree)
  - P*V: sequential MAC accumulation (8 elements)
  - Normalize: fp16_reciprocal + fp16_mul
"""
import struct
import os

# ---- Parameters ----
SEQ_LEN = 8
D_MODEL = 16
N_HEAD = 2
HEAD_DIM = 8
TILE_B_R = 4
TILE_B_C = 4

# ---- FP16 bit-level helpers ----
def fp16_unpack(raw):
    """Extract sign, exponent, mantissa from FP16 raw bits."""
    sign = (raw >> 15) & 1
    exp = (raw >> 10) & 0x1F
    man = raw & 0x3FF
    return sign, exp, man

def fp16_pack(sign, exp, man):
    """Pack sign, exponent, mantissa into FP16 raw bits."""
    return ((sign & 1) << 15) | ((exp & 0x1F) << 10) | (man & 0x3FF)

def fp16_is_zero(raw):
    """Check if FP16 value is zero (positive or negative)."""
    return (raw & 0x7FFF) == 0

def fp16_is_inf(raw):
    """Check if FP16 value is infinity."""
    sign, exp, man = fp16_unpack(raw)
    return exp == 0x1F and man == 0

def fp16_is_nan(raw):
    """Check if FP16 value is NaN."""
    sign, exp, man = fp16_unpack(raw)
    return exp == 0x1F and man != 0

def fp16_negate(raw):
    """Negate FP16 value (flip sign bit)."""
    return raw ^ 0x8000

# ---- FP16 Multiply (matching fp16_multiplier.sv EXACTLY) ----
def fp16_mul(a_raw, b_raw):
    """FP16 multiply with truncation (no rounding), matching fp16_multiplier.sv."""
    a_sign, a_exp, a_man = fp16_unpack(a_raw)
    b_sign, b_exp, b_man = fp16_unpack(b_raw)

    # Handle special cases
    a_is_zero = (a_exp == 0) and (a_man == 0)
    b_is_zero = (b_exp == 0) and (b_man == 0)
    a_is_inf = (a_exp == 0x1F) and (a_man == 0)
    b_is_inf = (b_exp == 0x1F) and (b_man == 0)
    a_is_nan = (a_exp == 0x1F) and (a_man != 0)
    b_is_nan = (b_exp == 0x1F) and (b_man != 0)

    if a_is_nan or b_is_nan:
        return 0x7E00  # NaN
    if a_is_zero or b_is_zero:
        result_sign = a_sign ^ b_sign
        return fp16_pack(result_sign, 0, 0)  # zero
    if a_is_inf or b_is_inf:
        result_sign = a_sign ^ b_sign
        return fp16_pack(result_sign, 0x1F, 0)  # inf

    # Implicit leading 1 (or 0 for denormals)
    a_frac = ((1 << 10) | a_man) if a_exp != 0 else a_man
    b_frac = ((1 << 10) | b_man) if b_exp != 0 else b_man

    # Multiply fractions: 11b x 11b = 22b
    mul_result = a_frac * b_frac  # 22 bits

    # Add exponents (subtract bias)
    exp_sum = a_exp + b_exp - 15  # can be negative

    # Sign
    result_sign = a_sign ^ b_sign

    # Check for zero result
    if mul_result == 0:
        return fp16_pack(result_sign, 0, 0)

    # Normalization (matching RTL exactly)
    if mul_result & (1 << 21):
        # MSB set, shift right
        norm_exp = (exp_sum & 0x3F) + 1
        norm_man = (mul_result >> 11) & 0x3FF
    else:
        # Already normalized
        norm_exp = exp_sum & 0x3F
        norm_man = (mul_result >> 10) & 0x3FF

    # Overflow/underflow detection (matching RTL)
    overflow = ((exp_sum & 0x20) and not (exp_sum & 0x10)) or (norm_exp == 0x1F)
    underflow = (exp_sum & 0x20) or (norm_exp == 0)

    if overflow:
        return fp16_pack(result_sign, 0x1F, 0)  # Inf
    if underflow:
        return fp16_pack(result_sign, 0, 0)  # Flush to zero

    return fp16_pack(result_sign, norm_exp & 0x1F, norm_man & 0x3FF)

# ---- FP16 Add (matching fp16_adder.sv EXACTLY) ----
def fp16_add(a_raw, b_raw):
    """FP16 add with truncation (no rounding), matching fp16_adder.sv."""
    a_sign, a_exp, a_man = fp16_unpack(a_raw)
    b_sign, b_exp, b_man = fp16_unpack(b_raw)

    # Handle special cases
    a_is_zero = (a_exp == 0) and (a_man == 0)
    b_is_zero = (b_exp == 0) and (b_man == 0)
    a_is_inf = (a_exp == 0x1F) and (a_man == 0)
    b_is_inf = (b_exp == 0x1F) and (b_man == 0)
    a_is_nan = (a_exp == 0x1F) and (a_man != 0)
    b_is_nan = (b_exp == 0x1F) and (b_man != 0)

    if a_is_nan or b_is_nan:
        return 0x7E00  # NaN
    if a_is_inf and b_is_inf:
        if a_sign != b_sign:
            return 0x7E00  # inf - inf = NaN
        return a_raw  # same sign inf
    if a_is_inf:
        return a_raw
    if b_is_inf:
        return b_raw

    # Implicit leading 1 (or 0 for denormals)
    a_frac = ((1 << 10) | a_man) if a_exp != 0 else a_man
    b_frac = ((1 << 10) | b_man) if b_exp != 0 else b_man

    # Exponent alignment
    if a_exp >= b_exp:
        exp_diff = a_exp - b_exp
        larger_exp = a_exp
        aligned_a = a_frac
        aligned_b = b_frac >> exp_diff if exp_diff <= 10 else 0
    else:
        exp_diff = b_exp - a_exp
        larger_exp = b_exp
        aligned_a = a_frac >> exp_diff if exp_diff <= 10 else 0
        aligned_b = b_frac

    # Addition (with sign)
    if a_sign == b_sign:
        sum_frac = (aligned_a + aligned_b) & 0xFFF  # 12 bits
        sum_sign = a_sign
    else:
        if aligned_a >= aligned_b:
            sum_frac = (aligned_a - aligned_b) & 0xFFF
            sum_sign = a_sign
        else:
            sum_frac = (aligned_b - aligned_a) & 0xFFF
            sum_sign = b_sign

    # Check zero
    if sum_frac == 0:
        return fp16_pack(0, 0, 0)  # positive zero

    # Normalization (matching RTL priority encoder: bits 11-8 only)
    norm_exp = larger_exp
    norm_man = sum_frac & 0x3FF

    if sum_frac & (1 << 11):
        # Overflow in fraction, shift right
        norm_exp = larger_exp + 1
        norm_man = (sum_frac >> 1) & 0x3FF
    elif sum_frac & (1 << 10):
        # Already normalized
        norm_man = sum_frac & 0x3FF
    elif sum_frac & (1 << 9):
        norm_exp = larger_exp - 1
        norm_man = (sum_frac & 0x1FF)  # bits [8:0]
    elif sum_frac & (1 << 8):
        norm_exp = larger_exp - 2
        norm_man = (sum_frac & 0xFF)  # bits [7:0]
    else:
        # Very small or zero
        norm_exp = 0
        norm_man = 0

    # Overflow/underflow
    if norm_exp >= 0x1F and (norm_exp & 0x1F) == 0x1F:
        return fp16_pack(sum_sign, 0x1F, 0)  # Inf
    if norm_exp == 0 and norm_man != 0:
        # Underflow - flush to zero (matching RTL)
        return fp16_pack(0, 0, 0)

    return fp16_pack(sum_sign, norm_exp & 0x1F, norm_man & 0x3FF)

# ---- FP16 Subtract (matching flash_attention_core.sv: negate b, then add) ----
def fp16_sub(a_raw, b_raw):
    """FP16 subtract: a - b = a + (-b)."""
    return fp16_add(a_raw, fp16_negate(b_raw))

# ---- FP16 MAC (sequential accumulation matching fp16_mac.sv) ----
def fp16_mac(acc_raw, a_raw, b_raw):
    """MAC: acc + a*b, using fp16_mul then fp16_add."""
    product = fp16_mul(a_raw, b_raw)
    return fp16_add(acc_raw, product)

# ---- FP16 dot product (sequential MAC, matching MAC array behavior) ----
def hw_dot_fp16(a_raw_arr, b_raw_arr):
    """FP16 dot product: sequential MAC accumulation, 8 elements."""
    acc = 0x0000  # positive zero
    for k in range(len(a_raw_arr)):
        acc = fp16_mac(acc, a_raw_arr[k], b_raw_arr[k])
    return acc

# ---- FP16 Exp LUT (matching fp16_exp_lut.sv EXACTLY) ----
EXP_LUT = [
    0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00,
    0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00,
    0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00, 0x3C00,
    0x3C00, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF,
    0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFF, 0x3BFE, 0x3BFE, 0x3BFE,
    0x3BFE, 0x3BFE, 0x3BFE, 0x3BFD, 0x3BFD, 0x3BFD, 0x3BFD, 0x3BFC,
    0x3BFC, 0x3BFC, 0x3BFB, 0x3BFB, 0x3BFA, 0x3BFA, 0x3BF9, 0x3BF9,
    0x3BF8, 0x3BF7, 0x3BF6, 0x3BF5, 0x3BF4, 0x3BF3, 0x3BF2, 0x3BF1,
    0x3BF0, 0x3BEE, 0x3BEC, 0x3BEA, 0x3BE8, 0x3BE6, 0x3BE4, 0x3BE2,
    0x3BE0, 0x3BDC, 0x3BD8, 0x3BD4, 0x3BD1, 0x3BCD, 0x3BC9, 0x3BC5,
    0x3BC1, 0x3BB9, 0x3BB2, 0x3BAA, 0x3BA2, 0x3B9B, 0x3B93, 0x3B8B,
    0x3B84, 0x3B75, 0x3B66, 0x3B57, 0x3B49, 0x3B3A, 0x3B2C, 0x3B1E,
    0x3B0F, 0x3AF3, 0x3AD8, 0x3ABD, 0x3AA2, 0x3A88, 0x3A6E, 0x3A54,
    0x3A3B, 0x3A0A, 0x39DA, 0x39AC, 0x3980, 0x3954, 0x392A, 0x3902,
    0x38DA, 0x388F, 0x3848, 0x3806, 0x378F, 0x371A, 0x36AB, 0x3644,
    0x35E3, 0x3532, 0x3496, 0x340C, 0x3324, 0x324D, 0x3190, 0x30E8,
    0x3055, 0x2EBF, 0x2D41, 0x2C17, 0x2A5F, 0x28F7, 0x27BB, 0x2605,
    0x24B0, 0x21B0, 0x1EE6, 0x1C2F, 0x1914, 0x1628, 0x1378, 0x1088,
    0x0D7F, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
]

def hw_exp_lut(x_raw):
    """Mimic fp16_exp_lut.sv behavior exactly."""
    sign, exp, man = fp16_unpack(x_raw)

    is_neg = (sign == 1)
    is_inf = (exp == 0x1F) and (man == 0)
    is_zero_or_denorm = (exp == 0)

    if is_inf and is_neg:
        return 0x0000  # -inf → 0
    elif not is_neg or is_zero_or_denorm:
        return 0x3C00  # positive/zero/denorm → 1.0
    else:
        lut_idx = (exp << 3) | (man >> 7)
        return EXP_LUT[lut_idx]

# ---- FP16 Reciprocal LUT (matching fp16_reciprocal.sv EXACTLY) ----
RECIP_LUT = [
    0x3C00, 0x3BE0, 0x3BC2, 0x3BA4, 0x3B88, 0x3B6C, 0x3B50, 0x3B36,
    0x3B1C, 0x3B04, 0x3AEB, 0x3AD4, 0x3ABD, 0x3AA6, 0x3A90, 0x3A7B,
    0x3A66, 0x3A52, 0x3A3E, 0x3A2B, 0x3A18, 0x3A06, 0x39F4, 0x39E3,
    0x39D1, 0x39C1, 0x39B0, 0x39A0, 0x3991, 0x3981, 0x3972, 0x3964,
    0x3955, 0x3947, 0x3939, 0x392C, 0x391F, 0x3912, 0x3905, 0x38F9,
    0x38EC, 0x38E0, 0x38D5, 0x38C9, 0x38BE, 0x38B2, 0x38A8, 0x389D,
    0x3892, 0x3888, 0x387E, 0x3874, 0x386A, 0x3860, 0x3857, 0x384D,
    0x3844, 0x383B, 0x3832, 0x382A, 0x3821, 0x3819, 0x3810, 0x3808,
]

def hw_reciprocal(x_raw):
    """Mimic fp16_reciprocal.sv behavior exactly."""
    sign, exp, man = fp16_unpack(x_raw)

    is_zero = (exp == 0) and (man == 0)
    recip_exp = 30 - exp  # 6-bit subtraction

    if is_zero:
        return fp16_pack(sign, 0x1F, 0)  # signed infinity
    elif recip_exp & 0x20:  # bit 5 set → negative exponent → underflow
        return fp16_pack(sign, 0, 0)  # signed zero
    elif (recip_exp & 0x1F) == 0x1F:
        return fp16_pack(sign, 0x1F, 0)  # signed infinity
    else:
        lut_idx = man >> 4  # top 6 bits of mantissa
        lut_entry = RECIP_LUT[lut_idx]
        lut_man = lut_entry & 0x3FF
        return fp16_pack(sign, recip_exp & 0x1F, lut_man)

# ---- FP16 Comparator (matching fp16_comparator.sv EXACTLY) ----
def hw_max(a_raw, b_raw):
    """FP16 max: returns the larger value, tie goes to a."""
    a_sign, a_exp, a_man = fp16_unpack(a_raw)
    b_sign, b_exp, b_man = fp16_unpack(b_raw)

    a_is_nan = (a_exp == 0x1F) and (a_man != 0)
    b_is_nan = (b_exp == 0x1F) and (b_man != 0)

    if a_is_nan:
        return b_raw  # NaN never wins
    if b_is_nan:
        return a_raw  # a wins if b is NaN

    if a_sign != b_sign:
        # Different signs: positive wins
        return a_raw if a_sign == 0 else b_raw
    elif a_sign == 0:
        # Both positive
        if a_exp != b_exp:
            return a_raw if a_exp > b_exp else b_raw
        else:
            return a_raw if a_man >= b_man else b_raw  # tie → a
    else:
        # Both negative: smaller magnitude = larger value
        if a_exp != b_exp:
            return a_raw if a_exp < b_exp else b_raw
        else:
            return a_raw if a_man <= b_man else b_raw  # tie → a

# ---- FP16 Row Max (binary tree, matching fp16_rowmax.sv) ----
def hw_rowmax_tree(data):
    """FP16 row max using binary tree, matching fp16_rowmax.sv."""
    n = len(data)
    if n == 1:
        return data[0]
    elif n == 2:
        return hw_max(data[0], data[1])
    else:
        half = n // 2
        left = hw_rowmax_tree(data[:half])
        right = hw_rowmax_tree(data[half:])
        return hw_max(left, right)

# ---- FP16 Row Sum (binary tree, matching fp16_rowsum.sv) ----
def hw_rowsum_tree(data):
    """FP16 row sum using binary tree, matching fp16_rowsum.sv."""
    n = len(data)
    if n == 1:
        return data[0]
    elif n == 2:
        return fp16_add(data[0], data[1])
    else:
        half = n // 2
        left = hw_rowsum_tree(data[:half])
        right = hw_rowsum_tree(data[half:])
        return fp16_add(left, right)

# ---- Main computation ----
def compute_attention_fp16(Q, K, V, scale_hex):
    """Compute attention using FP16 arithmetic matching the hardware pipeline.
    Q, K, V: flat arrays of FP16 raw values, length SEQ_LEN * D_MODEL
    Returns: O flat array of FP16 raw values, length SEQ_LEN * D_MODEL
    """
    O_raw = [0x0000] * (SEQ_LEN * D_MODEL)

    for h in range(N_HEAD):
        hd_start = h * HEAD_DIM

        for tile_row in range(SEQ_LEN // TILE_B_R):
            row_start = tile_row * TILE_B_R

            # Initialize accumulators
            m_accum = [0xFC00] * TILE_B_R  # -inf in FP16
            l_accum = [0x0000] * TILE_B_R  # 0.0
            o_accum = [[0x0000] * HEAD_DIM for _ in range(TILE_B_R)]

            for inner in range(SEQ_LEN // TILE_B_C):
                # ---- S = Q_tile @ K_tile^T (FP16 dot product, 8 elements) ----
                S_tile = [[0x0000] * (2 * TILE_B_C) for _ in range(TILE_B_R)]

                for r in range(TILE_B_R):
                    q_row = row_start + r
                    # S_tile[r][0..3] = Q[q_row] dot K[inner*4 + 0..3]
                    for c in range(TILE_B_C):
                        k_row = inner * TILE_B_C + c
                        q_vec = [Q[q_row * D_MODEL + hd_start + k] for k in range(HEAD_DIM)]
                        k_vec = [K[k_row * D_MODEL + hd_start + k] for k in range(HEAD_DIM)]
                        S_tile[r][c] = hw_dot_fp16(q_vec, k_vec)

                    # S_tile[r][4..7] = Q[q_row] dot K[inner*4 + 4..7]
                    for c in range(TILE_B_C):
                        k_row = inner * TILE_B_C + TILE_B_C + c
                        if k_row < SEQ_LEN:
                            k_vec = [K[k_row * D_MODEL + hd_start + k] for k in range(HEAD_DIM)]
                        else:
                            k_vec = [0x0000] * HEAD_DIM
                        S_tile[r][c + TILE_B_C] = hw_dot_fp16(q_vec, k_vec)

                # ---- S_scaled = S_tile * scale (FP16 multiply) ----
                S_scaled = [[0x0000] * (2 * TILE_B_C) for _ in range(TILE_B_R)]
                for r in range(TILE_B_R):
                    for c in range(2 * TILE_B_C):
                        S_scaled[r][c] = fp16_mul(S_tile[r][c], scale_hex)

                # ---- Softmax: rowmax, m_new, P = exp(S_scaled - m_new) ----
                rowmax = [0x0000] * TILE_B_R
                for r in range(TILE_B_R):
                    rowmax[r] = hw_rowmax_tree(S_scaled[r])

                m_new = [0x0000] * TILE_B_R
                for r in range(TILE_B_R):
                    m_new[r] = hw_max(m_accum[r], rowmax[r])

                P_tile = [[0x0000] * (2 * TILE_B_C) for _ in range(TILE_B_R)]
                for r in range(TILE_B_R):
                    for c in range(2 * TILE_B_C):
                        sub = fp16_sub(S_scaled[r][c], m_new[r])
                        P_tile[r][c] = hw_exp_lut(sub)

                # ---- rowsum(P) — tree reduction matching fp16_rowsum.sv ----
                rowsum = [0x0000] * TILE_B_R
                for r in range(TILE_B_R):
                    rowsum[r] = hw_rowsum_tree(P_tile[r])

                # ---- correction = exp(m_accum - m_new) ----
                corr = [0x0000] * TILE_B_R
                for r in range(TILE_B_R):
                    sub = fp16_sub(m_accum[r], m_new[r])
                    corr[r] = hw_exp_lut(sub)

                # ---- l_new = corr * l_accum + rowsum ----
                l_new = [0x0000] * TILE_B_R
                for r in range(TILE_B_R):
                    l_new[r] = fp16_add(fp16_mul(corr[r], l_accum[r]), rowsum[r])

                # ---- P*V (FP16 MAC, 8 elements) ----
                pv = [[0x0000] * HEAD_DIM for _ in range(TILE_B_R)]
                for r in range(TILE_B_R):
                    for c_idx in range(HEAD_DIM):
                        s = 0x0000  # acc = 0
                        for k in range(2 * TILE_B_C):
                            if k < TILE_B_C:
                                v_row = inner * TILE_B_C + k
                            else:
                                v_row = inner * TILE_B_C + TILE_B_C + (k - TILE_B_C)
                            if v_row < SEQ_LEN:
                                v_val = V[v_row * D_MODEL + hd_start + c_idx]
                            else:
                                v_val = 0x0000
                            s = fp16_mac(s, P_tile[r][k], v_val)
                        pv[r][c_idx] = s

                # ---- Update O: o_accum = corr * o_accum + pv ----
                for r in range(TILE_B_R):
                    for c in range(HEAD_DIM):
                        o_accum[r][c] = fp16_add(fp16_mul(corr[r], o_accum[r][c]), pv[r][c])

                # ---- Update m/l accumulators ----
                m_accum = m_new[:]
                l_accum = l_new[:]

            # ---- Normalize: O = o_accum / l_accum ----
            for r in range(TILE_B_R):
                recip = hw_reciprocal(l_accum[r])
                for c in range(HEAD_DIM):
                    O_raw[(row_start + r) * D_MODEL + hd_start + c] = fp16_mul(o_accum[r][c], recip)

    return O_raw

def load_hex(path, n):
    vals = []
    with open(path) as f:
        for i, line in enumerate(f):
            if i >= n: break
            vals.append(int(line.strip(), 16))
    return vals

def fp16_to_hex(val):
    return f'{val:04X}'

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    golden_dir = os.path.join(script_dir, 'golden')
    q_hex = load_hex(f'{golden_dir}/q_input.hex', 128)
    k_hex = load_hex(f'{golden_dir}/k_input.hex', 128)
    v_hex = load_hex(f'{golden_dir}/v_input.hex', 128)

    # Scale factor: 1/sqrt(8) ≈ 0.3535, matching RTL 0x35A8
    scale_hex = 0x35A8

    print("Computing FP16-accurate attention (bit-level matching RTL)...")
    O_raw = compute_attention_fp16(q_hex, k_hex, v_hex, scale_hex)

    # Save as hex
    with open(f'{golden_dir}/attention_output.hex', 'w') as f:
        for val in O_raw:
            f.write(f'{val:04X}\n')

    # Also save as binary (FP16 little-endian)
    import struct
    with open(f'{golden_dir}/attention_output.bin', 'wb') as f:
        for val in O_raw:
            f.write(struct.pack('<H', val))

    print(f"Output saved to {golden_dir}/attention_output.hex")
    print(f"Sample O[0]: {[fp16_to_hex(v) for v in O_raw[:8]]}")
    print(f"Sample O[8]: {[fp16_to_hex(v) for v in O_raw[8:16]]}")

if __name__ == '__main__':
    main()
