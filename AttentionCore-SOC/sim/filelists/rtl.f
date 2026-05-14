// RTL filelist for AttentionCore-SOC
// Packages first, then leaf modules before top modules

+incdir+../rtl/src
+incdir+../rtl/include
+incdir+../rtl/pkg

// Package
../rtl/pkg/soc_params_pkg.sv

// FP16 leaf units
../rtl/src/fp16_to_fp32.sv
../rtl/src/fp32_to_fp16.sv
../rtl/src/fp32_adder.sv
../rtl/src/fp16_adder.sv
../rtl/src/fp16_multiplier.sv
../rtl/src/fp16_comparator.sv
../rtl/src/fp16_exp_lut.sv
../rtl/src/fp16_rowmax.sv
../rtl/src/fp16_rowsum.sv

// FP16 MAC and array
../rtl/src/fp16_mac.sv
../rtl/src/fp16_mac_array.sv

// Attention building blocks
../rtl/src/causal_mask.sv
../rtl/src/qkv_buffer.sv
../rtl/src/pipeline_buffer.sv
../rtl/src/gelu_hw.sv
../rtl/src/layernorm_hw.sv
../rtl/src/residual_add.sv
../rtl/src/flash_attention_core.sv
../rtl/src/multi_head_scheduler.sv

// Engines
../rtl/src/attention_engine.sv
../rtl/src/mlp_engine.sv

// Control and peripherals
../rtl/src/ctrl_regs.sv
../rtl/src/uart_top.sv
../rtl/src/gpio_top.sv
../rtl/src/timer_top.sv

// SRAM models
../rtl/src/sram_single_port.sv
../rtl/src/sram_dual_port.sv

// RISC-V core
../rtl/src/riscv_core.sv

// APB interconnect
../rtl/src/apb_interconnect.sv

// Top-level
../rtl/src/attentioncore_soc_top.sv
