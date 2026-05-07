# UART Packet Controller

## 项目概述

UART Packet Controller是一个可配置的UART包控制器，用作小型嵌入式外设控制器。该设计同时包含UART包接口和APB-Lite主机控制接口。

## 目录结构

```
Uart_Controller/
├── README.md                    # 本文件
├── project.yaml                 # 项目配置
├── spec/                        # 设计规格说明
│   └── DESIGN_SPEC.md
├── rtl/                         # RTL源码
│   └── src/                     # 14个RTL模块
├── dv/                          # 验证环境
│   ├── uvm/                     # UVM组件
│   │   ├── agents/              # UART和APB Agent
│   │   ├── env/                 # UVM Environment
│   │   ├── sequences/           # 测试序列
│   │   ├── tests/               # 测试用例
│   │   └── scoreboard/          # 记分板
│   └── tb/                      # Testbench
├── sim/                         # 仿真目录
│   ├── Makefile                 # 仿真脚本
│   ├── filelists/               # 文件列表
│   └── scripts/                 # 辅助脚本
└── docs/                        # 文档
    ├── design_document.md       # 设计文档
    ├── verification_report.md   # 验证报告
    └── version_history.md       # 版本记录
```

## 快速开始

### 环境要求

- Synopsys VCS (O-2018.09-SP2或更高版本)
- Python 3.6+
- UVM 1.2

### 编译和仿真

```bash
cd sim

# 编译
make compile

# 运行全功能测试
make run UVM_TEST=full_function_test SEED=1

# 运行特定测试
make run UVM_TEST=ping_test SEED=1
make run UVM_TEST=reg_access_test SEED=1
make run UVM_TEST=mem_access_test SEED=1

# 运行所有测试
make uvm_tests

# 查看波形
make run UVM_TEST=full_function_test SEED=1 WAVE=1
make verdi UVM_TEST=full_function_test SEED=1

# 清理
make clean
```

### 可用测试

| 测试名称 | 描述 |
|----------|------|
| ping_test | PING命令基本测试 |
| reg_access_test | 寄存器读写测试 |
| mem_access_test | Memory Window访问测试 |
| full_function_test | 全功能验证测试 |

## 主要特性

- **全双工UART接口**：支持独立的RX和TX数据通路
- **APB-Lite接口**：用于配置、状态读取和调试访问
- **9种命令操作码**：PING、REG_READ/WRITE、MEM_READ/WRITE、STATUS_READ、FIFO_STATUS、LOOPBACK_CFG、SOFT_RESET
- **CRC-8校验**：保证数据传输完整性
- **错误检测**：支持CRC错误、长度错误、超时错误、帧错误等多种错误检测
- **中断支持**：可配置的中断源和掩码
- **环回模式**：支持UART诊断环回

## 设计参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| CLK_FREQ_HZ | 50 MHz | 系统时钟频率 |
| BAUD_RATE | 115200 | UART波特率 |
| FIFO_DEPTH | 32 | FIFO深度 |
| MAX_PAYLOAD_BYTES | 16 | 最大Payload长度 |

## 文档

- [设计规格说明](spec/DESIGN_SPEC.md) - 详细的设计规格
- [设计文档](docs/design_document.md) - 架构和接口说明
- [验证报告](docs/verification_report.md) - 验证过程和结果
- [版本记录](docs/version_history.md) - 版本变更历史

## 联系方式

如有问题或建议，请通过项目issue系统反馈。

---

版本：v1.0
最后更新：2026年5月7日
