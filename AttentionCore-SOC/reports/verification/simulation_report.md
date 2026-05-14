# 仿真验证报告

**项目**: AttentionCore-SOC
**日期**: 2026-05-14
**阶段**: UVM Verification Passed

## 仿真环境

- **仿真器**: Synopsys VCS O-2018.09-SP2
- **验证方法学**: UVM 1.2
- **测试平台**: dv/tb/uvm_tb_top.sv
- **验证框架**: dv/uvm/ (APB Agent + Environment + Scoreboard)

## UVM 验证架构

```
uvm_tb_top
  ├── apb_if (32-bit APB interface)
  ├── attentioncore_soc_top (DUT, test_mode_i=1)
  └── run_test()
       └── attn_base_test
            └── attn_env
                 ├── apb_agt (APB Agent, active)
                 │    ├── apb_driver
                 │    ├── apb_monitor
                 │    └── apb_sequencer
                 └── scb (Scoreboard)
                      ├── 寄存器影子模型
                      └── SRAM 影子模型
```

## 测试用例

| 测试 | 覆盖点 | SEED=1 | SEED=2 | SEED=3 |
|------|--------|--------|--------|--------|
| sram_smoke_test | 10个SRAM区域读写 | PASS | PASS | PASS |
| reg_access_test | 控制寄存器读写/只读/W1C/auto-clear | PASS | PASS | PASS |
| attn_engine_test | Attention Engine 启动/状态/中断 | PASS | PASS | PASS |
| gpio_loopback_test | GPIO 输出/输入回环 | PASS | PASS | PASS |
| timer_test | Timer 使能/计数/中断/清除 | PASS | PASS | PASS |
| irq_test | 中断使能/状态/清除全流程 | PASS | PASS | PASS |
| random_apb_test | 随机APB事务压力测试 | PASS | PASS | PASS |
| unmapped_addr_test | 未映射地址 pslverr | PASS | PASS | PASS |

**回归结果**: 8 测试 × 3 种子 = 24 次运行，全部通过，0 UVM_ERROR，0 UVM_FATAL

## Directed 测试（补充）

| 测试 | 覆盖点 | 结果 |
|------|--------|------|
| fp16_adder_test | FP16 加法器（10项） | 10 PASS, 0 FAIL |
| fp16_mac_test | FP16 MAC 单元（3项） | 3 PASS, 0 FAIL |
| fp16_mac_array_test | 4×4 MAC 阵列（9项） | 9 PASS, 0 FAIL |
| tb_attentioncore_soc | SOC 集成（19项） | 19 PASS, 0 FAIL |

## 验证覆盖总结

| 验证层级 | 内容 | 状态 |
|----------|------|------|
| L0 | FP16 MAC 阵列 | PASS (directed) |
| L8 | SOC 集成 (SRAM/APB/GPIO/Timer/AttnEngine/IRQ) | PASS (UVM + directed) |

## RTL Bug 修复记录

| Bug | 修复 |
|-----|------|
| attention_engine 缺少 WEIGHT_BASE/FEATURE_BASE/KVCACHE_BASE 读回逻辑 | 添加寄存器声明、复位值、写逻辑和读逻辑 |

## 编译和运行命令

```bash
cd sim

# 编译 UVM 测试平台
make -f Makefile.uvm compile

# 运行单个测试
make -f Makefile.uvm run UVM_TEST=sram_smoke_test SEED=1

# 运行回归测试
make -f Makefile.uvm regress TESTS="sram_smoke_test reg_access_test attn_engine_test gpio_loopback_test timer_test irq_test random_apb_test unmapped_addr_test" SEEDS="1 2 3"

# 清理
make -f Makefile.uvm clean
```

## 待完善项

1. **Exp/Rsqrt/GELU LUT**: 需要填充正确的函数值
2. **RISC-V 核心**: 当前为简化版本，需要替换为 picorv32
3. **Golden Model**: 需要创建 Python golden model 用于 bit-true 对比
4. **Coverage**: 需要添加功能覆盖率模型
