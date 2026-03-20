# AI-HDL 2026 — Design Phase 1 Report
**Project:** 4×4 Systolic Array AI Accelerator  
**Team:** Oreoluwa16  
**Date:** March 2026  
**Base Core:** TinyQV RISC-V (ttsky25a)

---

## 1. Design Choice & Motivation

For Design Phase 1 we implemented a 4×4 Systolic Array MAC accelerator.
This module enables the TinyQV RISC-V core to offload matrix multiplication
(C = A × B) to dedicated hardware — the fundamental bottleneck in neural
network inference.

A systolic array was chosen because:
- Data flows rhythmically through a grid of Processing Elements (PEs)
- Each PE computes acc += a_in × b_in every clock cycle
- All 16 PEs operate in parallel — O(N) latency vs O(N³) in software
- Regular structure is highly synthesizable and scalable
- Directly inspired by Google's TPU v1 architecture

---

## 2. Architecture

### Processing Element (PE)
- Inputs: a_in [7:0] (horizontal), b_in [7:0] (vertical), en, clk, rst_n
- Outputs: a_out [7:0] (pass-through right), b_out [7:0] (pass-through down)
- Operation: acc <= acc + (a_in * b_in) each enabled clock cycle
- Accumulator: 32-bit (prevents overflow for 8-bit × 8-bit × 4 inputs)

### Data Flow
Data is fed in a skewed (diagonal wavefront) pattern over 7 steps.
After 7 feed steps + 4 drain cycles, all 16 results are valid.

### FSM States
| State | Description |
|-------|-------------|
| S_IDLE | Waits for CTRL.start = 1 |
| S_FEED | Skewed feed for 7 cycles |
| S_WAIT | 4 drain cycles, latches results |
| S_DONE | Asserts IRQ, holds results |

### Register Map (MMIO)
| Address | Register | Description |
|---------|----------|-------------|
| 0x00–0x0F | MAT_A | Matrix A elements (8-bit) |
| 0x10–0x1F | MAT_B | Matrix B elements (8-bit) |
| 0x20 | CTRL | Bit 0 = Start |
| 0x24 | STATUS | Bit 0 = Done, Bit 1 = Busy |
| 0x28–0x67 | MAT_C | Result matrix (32-bit each) |

---

## 3. Verification Results

Testbench: tb/tb_systolic_array.v  
Simulator: Icarus Verilog 11.0

| Test | Description | Result |
|------|-------------|--------|
| T1 | Identity × Identity = Identity | PASS (16/16) |
| T2 | A × Identity = A | PASS (16/16) |
| T3 | All-ones × All-ones (each = 4) | PASS (16/16) |
| T4 | All-15s × All-15s (each = 900) | PASS (16/16) |
| T5 | Zero matrix (all = 0) | PASS (16/16) |

**Total: 80/80 PASSED**

---

## 4. Synthesis Results (Yosys Baseline)

Tool: Yosys 0.9 | Target: Generic gate library

| Metric | Value |
|--------|-------|
| Total cells (flattened) | 14,492 |
| Flip-flops | 1,649 |
| MUX cells | 2,886 |
| Logic gates | 9,957 |
| PE cells (per instance) | 577 |
| PE instances | 16 |
| Wires | 11,570 |
| Problems found | 0 |

FSM correctly extracted and re-encoded to one-hot by Yosys.

---

## 5. AI Tool Usage

All LLM interactions are documented in llm_logs/prompt_log.md.
Primary tool: Claude Sonnet 4.6 via claude.ai.

Stages covered: architecture research, RTL generation, debugging,
testbench generation, synthesis guidance, and documentation.

---

## 6. Files

| File | Description |
|------|-------------|
| rtl/systolic_array.v | Full RTL (pe + systolic_array modules) |
| tb/tb_systolic_array.v | Testbench — 80/80 passing |
| synth/synth.ys | Yosys synthesis script |
| synth/synth_report.txt | Baseline synthesis report |
| llm_logs/prompt_log.md | All LLM prompt logs |
