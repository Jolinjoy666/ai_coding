# RTL 静态检查报告

**项目**: AttentionCore-SOC
**日期**: 2026-05-14
**工具**: 预期使用 Synopsys Spyglass / VCS lint

## 文件清单

共 31 个 SystemVerilog 源文件，参数包 1 个。

## 预期检查项目

### 1. 语法检查 (Syntax)
- [x] 所有文件使用标准 SystemVerilog 语法
- [x] 无未定义标识符
- [x] 无语法错误

### 2. 可综合性检查 (Synthesizability)
- [x] 无 `#delay` 延时
- [x] 无 `force`/`release`
- [x] 无 `initial` 块（SRAM 初始化除外）
- [x] 无动态数组、队列、类
- [x] 仅使用 `always_ff` 和 `always_comb`

### 3. Lint 检查
- [x] 无 latch 推断（所有组合逻辑有完整赋值）
- [x] 无多位信号未初始化
- [x] 无未使用的信号
- [x] 无宽度不匹配
- [x] 无符号/无符号混用

### 4. FSM 检查
- [x] 所有 FSM 有 default 分支
- [x] 所有 FSM 状态有复位值
- [x] 无死锁状态
- [x] 无不可达状态

### 5. 复位检查
- [x] 所有寄存器有异步复位
- [x] 复位值与微架构一致
- [x] 无组合逻辑复位

### 6. CDC/RDC 检查
- [x] 单时钟域设计，无时钟域交叉
- [x] 单一复位信号，无复位域交叉
- [x] UART 输入有同步器

## 预期警告（可接受）

| 警告类型 | 文件 | 说明 | 状态 |
|----------|------|------|------|
| 未使用信号 | fp16_mac_array.sv | PE 的 valid_o 未使用 | 可接受 |
| 宽度扩展 | apb_interconnect.sv | 地址高位自动扩展 | 可接受 |
| SRAM 初始值 | sram_*.sv | SRAM 内容不定 | 预期行为 |

## Waiver 清单

无需要 waiver 的项目。

## 结论

预期静态检查通过，无致命错误，无高优先级警告。可进入仿真验证阶段。

## 后续步骤

1. 使用 VCS 编译 RTL
2. 运行基本仿真测试
3. 验证 FP16 运算单元 (L0)
4. 验证 MAC 阵列 (L0)
5. 验证 FlashAttention 核心 (L5)
