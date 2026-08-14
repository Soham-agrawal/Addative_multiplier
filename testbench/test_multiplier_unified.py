"""
cocotb testbench for multiplier_unified.

Drives the DUT with random and directed operand pairs across all 8
(mode_select, format_select, radix_select) configurations, and checks the
DUT's output bits match multiplier_unified_model.py (the golden reference
already validated against the paper's MRED numbers).

Run with: make
"""
import random

import cocotb
from cocotb.triggers import Timer

from multiplier_unified_model import multiplier_unified, rand_fp16, rand_bf16


async def apply_and_check(dut, num_a, num_b, format_select, radix_select, mode_select):
    """Drive one input combination and check the DUT's output bit pattern."""
    dut.num_a.value = num_a
    dut.num_b.value = num_b
    dut.format_select.value = format_select
    dut.radix_select.value = radix_select
    dut.mode_select.value = mode_select

    # multiplier_unified is purely combinational -- there's no clock to wait
    # on, but the simulator still needs a delta/time step to propagate the
    # new input values through the gate network before we sample prod.
    await Timer(1, units="ns")

    expected = multiplier_unified(num_a, num_b, format_select, radix_select, mode_select)
    actual = int(dut.prod.value)

    assert actual == expected, (
        f"MISMATCH cfg(mode={mode_select},fmt={format_select},radix={radix_select}) "
        f"a=0x{num_a:04x} b=0x{num_b:04x} -> DUT=0x{actual:04x} model=0x{expected:04x}"
    )


@cocotb.test()
async def test_directed_corners(dut):
    """A few hand-picked values per format, exercised across all 8 configs."""
    fp16_corners = [0x3C00, 0x4000, 0x3800, 0x7BFF, 0x0400, 0xBC00]  # 1.0, 2.0, 0.5, max, min-normal, -1.0
    bf16_corners = [0x3F80, 0x4000, 0x3F00, 0x7F7F, 0x0080, 0xBF80]

    for mode_select in (0, 1):
        for radix_select in (0, 1):
            for format_select, corners in ((1, fp16_corners), (0, bf16_corners)):
                for a in corners:
                    for b in corners:
                        await apply_and_check(dut, a, b, format_select, radix_select, mode_select)


@cocotb.test()
async def test_randomized_sweep(dut):
    """Randomized operands, all 8 configs, DUT checked bit-exact against the model."""
    random.seed(1234)
    n_per_config = 500  # bump this up for a more thorough run; kept small for CI speed

    for mode_select in (0, 1):
        for radix_select in (0, 1):
            for format_select in (0, 1):
                rand_fn = rand_fp16 if format_select else rand_bf16
                for _ in range(n_per_config):
                    a = rand_fn()
                    b = rand_fn()
                    await apply_and_check(dut, a, b, format_select, radix_select, mode_select)

    dut._log.info("All configs passed: %d vectors each", n_per_config)

'''
output -

  288.00ns INFO     cocotb.regression                  test_multiplier_unified.test_directed_corners passed
  288.00ns INFO     cocotb.regression                  running test_multiplier_unified.test_randomized_sweep (2/2)
                                                            Randomized operands, all 8 configs, DUT checked bit-exact against the model.
  4288.00ns INFO     cocotb.multiplier_unified          All configs passed: 500 vectors each
  4288.00ns INFO     cocotb.regression                  test_multiplier_unified.test_randomized_sweep passed
  4288.00ns INFO     cocotb.regression                  *******************************************************************************************************
                                                        ** TEST                                           STATUS  SIM TIME (ns)  REAL TIME (s)  RATIO (ns/s) **
                                                        *******************************************************************************************************
                                                        ** test_multiplier_unified.test_directed_corners   PASS         288.00           0.02      12120.08  **
                                                        ** test_multiplier_unified.test_randomized_sweep   PASS        4000.00           0.28      14179.97  **
                                                        *******************************************************************************************************
                                                        ** TESTS=2 PASS=2 FAIL=0 SKIP=0                                4288.00           0.31      13919.36  **
                                                        *******************************************************************************************************
'''
