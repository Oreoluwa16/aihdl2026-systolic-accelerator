# AI-HDL 2026 — LLM Prompt Log
**Project:** 4×4 Systolic Array AI Accelerator  
**Team:** Oreoluwa16  
**Competition:** AI-HDL 2026 Design Phase 1  
**Primary Tool:** Claude Sonnet 4.6 (claude.ai)

---

## Prompt #1 — 2026-03-20 — Architecture Research
**Tool:** Claude Sonnet 4.6  
**Purpose:** Understand systolic arrays before writing any code

### Prompt
```
I am implementing a 4x4 systolic array MAC accelerator in Verilog for
AI-HDL 2026. Explain: what is a systolic array, why is data fed in a
skewed diagonal pattern, what is weight-stationary dataflow, and what
should the latency be in clock cycles for a 4x4 array to complete one
matrix multiply?
```

### Response Summary
Claude explained systolic array principles (Kung & Leiserson 1978),
the critical insight that skewing input data by one cycle per row/column
correctly aligns data at each PE. Explained why the accumulator needs
32 bits (8×8=16 bit max, 4 accumulations need more headroom). Suggested
starting with a single PE module then composing into the array using
generate blocks. Latency = 7 feed steps + 4 drain cycles = 11 cycles.

### Files Affected
- Understanding used to design `rtl/systolic_array.v`

---

## Prompt #2 — 2026-03-20 — RTL Generation
**Tool:** Claude Sonnet 4.6  
**Purpose:** Generate the PE module and top-level systolic array

### Prompt
```
Write a synthesizable Verilog module called pe (Processing Element).
Inputs: clk, rst_n, en, a_in[7:0], b_in[7:0].
Outputs: a_out[7:0] registered pass-through, b_out[7:0] registered
pass-through, acc[31:0]. On each enabled clock: acc <= acc + a_in*b_in.
Then write the top-level 4x4 systolic_array with memory-mapped interface:
we, re, addr[7:0], wdata[31:0], rdata[31:0], ack, irq.
Matrix A at 0x00-0x0F, B at 0x10-0x1F, CTRL at 0x20, STATUS at 0x24,
result C at 0x28-0x67. FSM: IDLE->FEED(7 steps)->WAIT(4 drain)->DONE.
```

### Response Summary
Claude generated both modules. Initial version had a dual-driver bug
on ctrl_start — two always blocks both driving it caused FSM not to
start. Fixed by isolating ctrl_start exclusively to the write block
with auto-clear each cycle. FSM reads it but never writes it.

### Files Affected
- `rtl/systolic_array.v` — created

---

## Prompt #3 — 2026-03-20 — Debugging (PE accumulator not clearing)
**Tool:** Claude Sonnet 4.6  
**Purpose:** Fix testbench showing stale accumulator values between tests

### Prompt
```
My testbench runs 5 tests sequentially. Test 1 passes (Identity x
Identity). Test 3 (all-ones) shows diagonal values of 5 instead of 4.
Test 4 (all-15s) shows values of 5 instead of 900. This looks like the
PE accumulators are carrying over values from the previous test. How do
I clear them between tests?
```

### Response Summary
Claude confirmed the root cause: PE accumulators are reset only by
rst_n going low. The fix is to pulse rst_n between each test in the
testbench using a do_reset task. Also increased wait_done timeout from
200 to 500 cycles for safety. After fix: 80/80 tests passed.

### Files Affected
- `tb/tb_systolic_array.v` — added do_reset task, called between tests

---

## Prompt #4 — 2026-03-20 — Synthesis
**Tool:** Claude Sonnet 4.6  
**Purpose:** Generate Yosys script and interpret the stat output

### Prompt
```
Write a Yosys synthesis script for systolic_array.v targeting generic
gates. Run proc, opt, fsm, memory, synth passes and output a stat report
saved to synth_report.txt. Explain what the cell count, flip-flop count,
and wire numbers mean for estimating silicon area.
```

### Response Summary
Claude generated synth.ys. Synthesis completed with 0 problems.
Results: 14,492 total cells, 1,649 flip-flops, 2,886 MUX cells.
FSM correctly extracted and re-encoded to one-hot. Each PE instance
synthesizes to 577 cells × 16 = 9,232 cells just for the array.
Yosys 0.9 used; generic gate library (no sky130 liberty for this pass).

### Files Affected
- `synth/synth.ys` — created
- `synth/synth_report.txt` — generated

---

## Reflection

Using Claude as an AI-first design partner significantly accelerated
development. Architecture understanding that would take hours of reading
was compressed into focused conversation. RTL was generated correctly
on first attempt for the PE module. Debugging was efficient when exact
symptoms and code were provided. All AI outputs were verified by running
simulation — Claude was treated as a collaborator, not an oracle.
