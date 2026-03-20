# AI-HDL 2026 — LLM Prompt Log
**Project:** 4x4 Systolic Array AI Accelerator  
**Team:** Oreoluwa16  
**Competition:** AI-HDL 2026 Design Phase 1

---
## Prompt #1 — 2026-03-20 — Debugging
**Tool:** Claude Sonnet 4.6
**Purpose:** Fix dual-driver bug on ctrl_start causing FSM not to start

### Prompt
My systolic array testbench shows Timeout on tests 1 and 5, and stale
results on tests 2-4. The ctrl_start signal is driven by two always
blocks — the FSM auto-clears it and the write block sets it simultaneously.

### Response Summary
Claude identified that two always blocks driving ctrl_start caused a
race condition. Fix: move ctrl_start exclusively to the write block with
auto-clear each cycle. FSM reads it but never writes it. Also identified
that PE accumulators needed rst_n pulsed between tests to clear state.

### Files Affected
- `rtl/systolic_array.v` — separated ctrl_start driver to write block only
- `tb/tb_systolic_array.v` — added do_reset task between each test

---
## Prompt #2 — 2026-03-20 — Synthesis
**Tool:** Claude Sonnet 4.6
**Purpose:** Generate Yosys synthesis script and interpret stat output

### Prompt
Write a Yosys synthesis script for systolic_array.v that runs proc, opt,
fsm, memory passes and outputs a stat report. Also explain what the
cell count and wire numbers mean for area estimation.

### Response Summary
Claude generated synth.ys with the full synthesis flow. Synthesis
completed with 0 problems. Total flattened design = 14,492 cells,
1,649 flip-flops, 2,886 MUX cells. FSM correctly extracted and
re-encoded to one-hot. PE module = 577 cells × 16 instances.

### Files Affected
- `synth/synth.ys` — Yosys synthesis script
- `synth/synth_report.txt` — baseline synthesis report

---
