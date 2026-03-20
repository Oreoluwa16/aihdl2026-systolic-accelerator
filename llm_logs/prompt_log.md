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
