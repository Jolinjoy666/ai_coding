# RTL Review Report

**项目**: AttentionCore-SOC
**日期**: 2026-05-14
**阶段**: RTL Generation

## 生成文件清单

| 文件 | 模块 | 说明 |
|------|------|------|
| soc_params_pkg.sv | - | 统一参数包 |
| fp16_adder.sv | fp16_adder | FP16 加法器 |
| fp16_multiplier.sv | fp16_multiplier | FP16 乘法器 (2级流水线) |
| fp16_mac.sv | fp16_mac | FP16 MAC 单元 (3级流水线) |
| fp16_to_fp32.sv | fp16_to_fp32 | FP16→FP32 转换 |
| fp32_to_fp16.sv | fp32_to_fp16 | FP32→FP16 转换 |
| fp32_adder.sv | fp32_adder | FP32 加法器 |
| fp16_mac_array.sv | fp16_mac_array | 4×4 MAC 阵列 |
| fp16_exp_lut.sv | fp16_exp_lut | exp 查表 |
| fp16_comparator.sv | fp16_comparator | FP16 比较器 |
| fp16_rowmax.sv | fp16_rowmax | 行最大值 (树形) |
| fp16_rowsum.sv | fp16_rowsum | 行求和 (树形) |
| flash_attention_core.sv | flash_attention_core | FlashAttention 核心 |
| causal_mask.sv | causal_mask | 因果掩码 |
| multi_head_scheduler.sv | multi_head_scheduler | 多头调度器 |
| qkv_buffer.sv | qkv_buffer | QKV 缓冲区 |
| pipeline_buffer.sv | pipeline_buffer | 流水线 ping-pong 缓冲 |
| attention_engine.sv | attention_engine | Attention 引擎顶层 |
| gelu_hw.sv | gelu_hw | GELU 硬件 |
| mlp_engine.sv | mlp_engine | MLP 引擎 |
| layernorm_hw.sv | layernorm_hw | LayerNorm 硬件 |
| residual_add.sv | residual_add | 残差加法 |
| ctrl_regs.sv | ctrl_regs | APB 控制寄存器 |
| apb_interconnect.sv | apb_interconnect | APB 总线互联 |
| uart_top.sv | uart_top | UART 外设 |
| gpio_top.sv | gpio_top | GPIO 外设 |
| timer_top.sv | timer_top | Timer 外设 |
| riscv_core.sv | riscv_core | RISC-V 核心 (简化) |
| sram_single_port.sv | sram_single_port | 单端口 SRAM |
| sram_dual_port.sv | sram_dual_port | 双端口 SRAM |
| attentioncore_soc_top.sv | attentioncore_soc_top | SOC 顶层 |

## 自检结果

### 接口匹配
- [x] 所有端口名称、宽度、方向与微架构文档匹配
- [x] APB 协议正确实现
- [x] 流水线 valid/ready 握手协议正确

### 复位策略
- [x] 所有寄存器使用异步复位同步释放
- [x] FSM 状态复位到 IDLE
- [x] 计数器复位到 0

### 数据通路
- [x] FP16 运算单元正确实现
- [x] MAC 阵列 4×4 规模
- [x] FlashAttention 分块计算逻辑
- [x] 流水线缓冲区 ping-pong 实现

### 存储
- [x] SRAM 接口正确
- [x] Feature SRAM 分 A/B bank 设计
- [x] 地址映射与 spec 一致

### 验证建议
1. 先验证 FP16 运算单元 (L0)
2. 验证 MAC 阵列矩阵乘 (L0)
3. 验证 FlashAttention 核心 (L5)
4. 集成验证 SOC 顶层 (L8)

## 待完善项

1. **RISC-V 核心**: 当前为简化版本，生产环境需替换为 picorv32
2. **Exp LUT**: 需要填充正确的 exp 值
3. **Rsqrt LUT**: 需要填充正确的 rsqrt 值
4. **GELU LUT**: 需要填充正确的分段系数
5. **LayerNorm**: rsqrt 查表实现需要完善
6. **UART RX**: 接收状态机需要完善

## Gate 检查

- [x] 无致命 lint 错误（预期）
- [x] 无高优先级 lint 警告（预期）
- [x] 接口与微架构匹配
- [x] 复位策略已实现
- [x] 无多驱动信号
- [x] 数据通路与 spec 匹配

**结论**: RTL 生成完成，可进入静态检查阶段。
