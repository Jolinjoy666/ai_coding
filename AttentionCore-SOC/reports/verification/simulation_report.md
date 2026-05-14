# 仿真验证报告

**项目**: AttentionCore-SOC
**日期**: 2026-05-14
**阶段**: RTL Simulation

## 仿真环境

- **仿真器**: Synopsys VCS (预期)
- **波形查看**: Verdi
- **测试平台**: tb_attentioncore_soc.sv
- **测试用例**: fp16_mac_test.sv

## 测试用例

| 测试 | 目标 | 状态 |
|------|------|------|
| fp16_mac_test | FP16 MAC 单元基本功能 | 待运行 |
| soc_smoke | SOC 基本功能 | 待运行 |
| attn_basic | Attention 引擎基本功能 | 待运行 |

## 预期验证层级

| 层级 | 内容 | 状态 |
|------|------|------|
| L0 | FP16 MAC 阵列 | 待验证 |
| L1 | FP16 Softmax | 待验证 |
| L2 | FP16 LayerNorm | 待验证 |
| L3 | FP16 GELU | 待验证 |
| L4 | QKV 投影 | 待验证 |
| L5 | FlashAttention | 待验证 |
| L6 | 单层 Encoder | 待验证 |
| L7 | 2层推理 | 待验证 |
| L8 | SOC 集成 | 待验证 |
| L9 | 性能验证 | 待验证 |
| L10 | PPA 验证 | 待验证 |
| L11 | 应用验证 | 待验证 |

## 编译命令

```bash
# 编译 SOC
cd sim && make compile

# 运行 FP16 MAC 测试
make test_mac

# 运行 SOC 仿真
make sim_soc
```

## 待完善项

1. **Exp LUT**: 需要填充正确的 exp 值
2. **Rsqrt LUT**: 需要填充正确的 rsqrt 值
3. **GELU LUT**: 需要填充正确的分段系数
4. **RISC-V 核心**: 当前为简化版本，需要替换为 picorv32
5. **Golden Model**: 需要创建 Python golden model 用于对比

## 下一步

1. 运行 FP16 MAC 基本测试
2. 验证 FP16 运算单元正确性
3. 逐步验证各模块
4. 集成验证 SOC 顶层
5. 性能验证
