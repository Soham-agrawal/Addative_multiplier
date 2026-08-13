"""
Bit-accurate Python model of multiplier_unified (FPLM-1 / CLM, FP16 / bfloat16,
radix-2 / radix-4), for checking RTL changes against exact multiplication and
against the reference paper's reported MRED numbers before running a full
Verilog testbench.

Reference: Niu, Zhang, Jiang, Cockburn, Liu, Han, "Hardware-Efficient
Logarithmic Floating-Point Multipliers for Error-Tolerant Applications",
IEEE TCAS-I, vol. 71, no. 1, Jan 2024.

NOTE: this reflects the anti-log fix discussed — mode_select=0 (CLM) must NOT
double the log-domain remainder when msb_p=1; only mode_select=1 (FPLM) does.
Keep this file in sync with your actual RTL as you iterate.
"""
import random


def mask(v, bits):
    return v & ((1 << bits) - 1)


def multiplier_unified(num_a, num_b, format_select, radix_select, mode_select):
    """Bit-accurate model of the multiplier_unified Verilog module.

    num_a, num_b : 16-bit ints (FP16 or bfloat16 bit pattern, per format_select)
    format_select: 1 = FP16 (1-5-10), 0 = bfloat16 (1-8-7)
    radix_select : 1 = radix-4 truncated log domain, 0 = full radix-2
    mode_select  : 1 = FPLM-1 (double-sided error), 0 = CLM / plain Mitchell
    returns      : 16-bit int, product bit pattern in the same format as inputs
    """
    sign_a = (num_a >> 15) & 1
    sign_b = (num_b >> 15) & 1

    if format_select:  # FP16: 1-5-10
        exp_a = (num_a >> 10) & 0x1F
        exp_b = (num_b >> 10) & 0x1F
        raw_frac_a = num_a & 0x3FF
        raw_frac_b = num_b & 0x3FF
    else:  # bfloat16: 1-8-7, left-aligned into the shared 10-bit fraction bus
        exp_a = (num_a >> 7) & 0xFF
        exp_b = (num_b >> 7) & 0xFF
        raw_frac_a = ((num_a & 0x7F) << 3) & 0x3FF
        raw_frac_b = ((num_b & 0x7F) << 3) & 0x3FF

    bias = 15 if format_select else 127

    mant_a = (1 << 10) | raw_frac_a  # 11 bits, implicit leading 1
    mant_b = (1 << 10) | raw_frac_b
    msb_a = (mant_a >> 9) & 1
    msb_b = (mant_b >> 9) & 1
    mant_shift_a = mant_a >> 1
    mant_shift_b = mant_b >> 1

    if mode_select:  # FPLM-1: piecewise log approximation
        log_approx_a = ((1 << 10) | (mant_shift_a & 0x3FF)) if msb_a else (mant_a & 0x3FF)
        log_approx_b = ((1 << 10) | (mant_shift_b & 0x3FF)) if msb_b else (mant_b & 0x3FF)
    else:  # CLM: plain Mitchell, log2(1+k) =~ k, no correction
        log_approx_a = mant_a & 0x3FF
        log_approx_b = mant_b & 0x3FF

    # radix-4: truncate the LSB of the already-computed log approximation
    # (per Algorithm 1 in the paper), not the raw mantissa
    log_a_r4 = (log_approx_a >> 1) & 0x3FF
    log_b_r4 = (log_approx_b >> 1) & 0x3FF

    log_sum_r2 = mask(log_approx_a + log_approx_b, 12)
    log_sum_r4_pre = mask(log_a_r4 + log_b_r4, 11)
    log_sum_r4 = mask(log_sum_r4_pre << 1, 12)  # restore scale with a 0 LSB

    log_sum = log_sum_r4 if radix_select else log_sum_r2
    msb_p = (log_sum >> 10) & 1

    if mode_select:
        # FPLM-1: msb_p=1 means renormalize by doubling the remainder
        anti_log_shift = mask((log_sum & 0x3FF) << 1, 10)
        anti_log_mant = anti_log_shift if msb_p else (log_sum & 0x3FF)
    else:
        # CLM/Mitchell: mantissa fraction is always the remainder as-is;
        # msb_p only carries into the exponent, it does not reshape the mantissa
        anti_log_mant = log_sum & 0x3FF

    w1 = (~(msb_a | msb_b)) & 1
    w2 = (~(msb_a & msb_b)) & 1
    w3 = (w1 | msb_p) & 1
    w4 = (~(w2 & w3)) & 1

    carry = w4 if mode_select else msb_p
    exp_sum = mask(exp_a + exp_b - bias + carry, 9)
    sign = sign_a ^ sign_b

    if format_select:  # pack FP16
        return (sign << 15) | ((exp_sum & 0x1F) << 10) | (anti_log_mant & 0x3FF)
    else:  # pack bfloat16
        return (sign << 15) | ((exp_sum & 0xFF) << 7) | ((anti_log_mant >> 3) & 0x7F)


def fp16_to_float(u):
    sign = -1.0 if (u >> 15) & 1 else 1.0
    exp = (u >> 10) & 0x1F
    frac = u & 0x3FF
    if exp == 0:
        return sign * (frac / 1024.0) * 2 ** (-14)
    if exp == 31:
        return float("inf") if frac == 0 else float("nan")
    return sign * (1 + frac / 1024.0) * 2 ** (exp - 15)


def bf16_to_float(u):
    sign = -1.0 if (u >> 15) & 1 else 1.0
    exp = (u >> 7) & 0xFF
    frac = u & 0x7F
    if exp == 0:
        return sign * (frac / 128.0) * 2 ** (-126)
    if exp == 255:
        return float("inf") if frac == 0 else float("nan")
    return sign * (1 + frac / 128.0) * 2 ** (exp - 127)


def rand_fp16(exp_lo=10, exp_hi=20):
    """Random normal FP16 bit pattern; exponent range keeps products from
    overflowing/underflowing so you're measuring mantissa error, not range
    exhaustion (mirrors how the paper isolates mantissa error)."""
    s = random.randint(0, 1)
    e = random.randint(exp_lo, exp_hi)
    f = random.randint(0, 1023)
    return (s << 15) | (e << 10) | f


def rand_bf16(exp_lo=100, exp_hi=150):
    s = random.randint(0, 1)
    e = random.randint(exp_lo, exp_hi)
    f = random.randint(0, 127)
    return (s << 15) | (e << 7) | f


def mred(fmt, mode_select, radix_select, n=200_000, seed=None):
    """Mean Relative Error Distance, matching the paper's metric."""
    if seed is not None:
        random.seed(seed)
    to_f = fp16_to_float if fmt == "FP16" else bf16_to_float
    rand_fn = rand_fp16 if fmt == "FP16" else rand_bf16
    format_select = fmt == "FP16"
    errs = []
    for _ in range(n):
        a, b = rand_fn(), rand_fn()
        exact = to_f(a) * to_f(b)
        if exact == 0:
            continue
        approx = to_f(multiplier_unified(a, b, format_select, radix_select, mode_select))
        if approx != approx:  # NaN, skip (shouldn't happen with the safe exponent ranges)
            continue
        errs.append(abs(approx - exact) / abs(exact))
    return sum(errs) / len(errs)


if __name__ == "__main__":
    # Paper's Table I reference numbers (single/half-precision + bfloat16, MRED):
    #   FPLM-1     : FP16 0.0289, bf16 0.0302
    #   FPLM-1-r4  : FP16 0.0290, bf16 0.0330
    #   CLM-r4     : FP16 0.0397, bf16 0.0488
    checks = [
        ("CLM",       0, 0, "FP16", 0.0383), ("CLM",       0, 0, "bf16", 0.0383),
        ("FPLM-1",    1, 0, "FP16", 0.0289), ("FPLM-1",    1, 0, "bf16", 0.0302),
        ("FPLM-1-r4", 1, 1, "FP16", 0.0290), ("FPLM-1-r4", 1, 1, "bf16", 0.0330),
        ("CLM-r4",    0, 1, "FP16", 0.0397), ("CLM-r4",    0, 1, "bf16", 0.0488),
    ]
    for label, mode, radix, fmt, paper_val in checks:
        got = mred(fmt, mode, radix, seed=42)
        print(f"{fmt:5s} {label:10s} model={got:.4f}  paper={paper_val:.4f}")
# output -
# FP16  CLM        model=0.0384  paper=0.0383
# bf16  CLM        model=0.0384  paper=0.0383
# FP16  FPLM-1     model=0.0288  paper=0.0289
# bf16  FPLM-1     model=0.0282  paper=0.0302
# FP16  FPLM-1-r4  model=0.0289  paper=0.0290
# bf16  FPLM-1-r4  model=0.0282  paper=0.0330
# FP16  CLM-r4     model=0.0391  paper=0.0397
# bf16  CLM-r4     model=0.0384  paper=0.0488
