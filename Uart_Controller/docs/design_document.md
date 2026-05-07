# UART Packet Controller 设计文档

## 1. 设计概述

UART Packet Controller是一个可配置的UART包控制器，用作小型嵌入式外设控制器。该设计同时包含UART包接口和APB-Lite主机控制接口。

### 1.1 主要特性

- 全双工UART接口，RX与TX数据通路相互独立
- APB-Lite主机接口，用于配置、状态读取和调试访问
- 基于单系统时钟生成UART baud tick和oversample tick
- 支持9种命令操作码
- 支持多种错误检测机制
- 支持寄存器读写和Memory Window访问
- 支持中断和状态报告

### 1.2 设计参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| CLK_FREQ_HZ | 50,000,000 | 输入系统时钟频率 |
| BAUD_RATE | 115,200 | UART baud rate |
| OVERSAMPLE | 16 | UART RX过采样倍率 |
| DATA_WIDTH | 8 | UART byte宽度 |
| FIFO_DEPTH | 32 | RX/TX FIFO深度 |
| MAX_PAYLOAD_BYTES | 16 | 最大payload字节数 |
| MEM_ADDR_WIDTH | 4 | Memory Window地址宽度 |
| APB_ADDR_WIDTH | 8 | APB地址宽度 |
| APB_DATA_WIDTH | 32 | APB数据宽度 |
| TIMEOUT_BITS | 16 | 超时计数器宽度 |
| INTER_BYTE_TIMEOUT | 50,000 | 字节间超时周期数 |

## 2. 模块架构

### 2.1 模块列表

| 模块名 | 功能说明 |
|--------|----------|
| uart_packet_controller | 顶层集成模块 |
| apb_lite_slave | APB-Lite从接口前端 |
| baud_tick_gen | 波特率时钟生成器 |
| uart_rx | UART接收器 |
| uart_tx | UART发送器 |
| byte_fifo | 参数化同步FIFO |
| crc8_stream | CRC-8计算模块 |
| packet_parser | 包解析器 |
| command_arbiter | 命令仲裁器 |
| command_engine | 命令执行引擎 |
| reg_file | 寄存器文件 |
| memory_window | Memory Window |
| response_builder | 响应构建器 |
| irq_status_ctrl | 中断状态控制器 |

### 2.2 顶层接口

```
                    ┌─────────────────────────────┐
                    │    uart_packet_controller    │
                    │                             │
         clk ──────►│                             │
        rst_n ──────►│                             │
                    │                             │
     uart_rx_i ────►│                             ├────► uart_tx_o
                    │                             │
     cfg_enable ───►│                             │
      irq_clear ───►│                             │
                    │                             │
         paddr ────►│                             ├────► prdata
          psel ────►│                             ├────► pready
        penable ───►│                             ├────► pslverr
         pwrite ───►│                             │
         pwdata ───►│                             │
          pstrb ───►│                             │
                    │                             │
                    │                             ├────► irq_o
                    │                             ├────► busy_o
                    │                             ├────► rx_packet_count
                    │                             ├────► tx_packet_count
                    │                             ├────► error_count
                    │                             ├────► last_error
                    │                             ├────► soft_reset_seen
                    └─────────────────────────────┘
```

## 3. 命令集

### 3.1 命令列表

| Opcode | 名称 | Request Payload | Response Payload | 说明 |
|--------|------|-----------------|------------------|------|
| 0x01 | PING | none | 0xAA | 存活检测 |
| 0x10 | REG_READ | addr[7:0] | data[7:0] | 读取寄存器 |
| 0x11 | REG_WRITE | addr[7:0], data[7:0] | none | 写入寄存器 |
| 0x20 | MEM_READ | addr[7:0], len[7:0] | memory bytes | 读取Memory Window |
| 0x21 | MEM_WRITE | addr[7:0], data bytes | none | 写入Memory Window |
| 0x30 | STATUS_READ | none | status bytes | 返回状态信息 |
| 0x31 | FIFO_STATUS | none | FIFO status bytes | 返回FIFO状态 |
| 0x40 | LOOPBACK_CFG | enable[0] | none | 配置环回模式 |
| 0x7E | SOFT_RESET | 0xDE, 0xAD | none | 软复位 |

### 3.2 状态码

| Code | 名称 | 含义 |
|------|------|------|
| 0x00 | OK | 命令执行成功 |
| 0x01 | CRC_ERROR | CRC校验错误 |
| 0x02 | LENGTH_ERROR | 长度错误 |
| 0x03 | UNSUPPORTED_CMD | 不支持的命令 |
| 0x04 | ADDR_ERROR | 地址错误 |
| 0x05 | BUSY_ERROR | 忙错误 |
| 0x06 | TIMEOUT_ERROR | 超时错误 |
| 0x07 | FRAMING_ERROR | 帧错误 |
| 0x08 | FIFO_ERROR | FIFO错误 |
| 0x09 | APB_CONFLICT | APB冲突 |

## 4. 寄存器映射

| 地址 | 名称 | 访问类型 | 复位值 | 说明 |
|------|------|----------|--------|------|
| 0x00 | CTRL | RW | 0x01 | 控制寄存器 |
| 0x01 | IRQ_STATUS | RC | 0x00 | 中断状态(读清除) |
| 0x02 | IRQ_MASK | RW | 0x03 | 中断掩码 |
| 0x03 | LAST_STATUS | RO | 0x00 | 最近响应状态 |
| 0x04 | RX_COUNT_L | RO | 0x00 | 接收计数低字节 |
| 0x05 | RX_COUNT_H | RO | 0x00 | 接收计数高字节 |
| 0x06 | ERR_COUNT_L | RO | 0x00 | 错误计数低字节 |
| 0x07 | ERR_COUNT_H | RO | 0x00 | 错误计数高字节 |
| 0x08 | TX_COUNT_L | RO | 0x00 | 发送计数低字节 |
| 0x09 | TX_COUNT_H | RO | 0x00 | 发送计数高字节 |
| 0x0A | FIFO_WATERMARK | RW | 0x10 | FIFO水印阈值 |
| 0x0B | LOOPBACK_CTRL | RW | 0x00 | 环回控制 |
| 0x10-0x1F | MEM_DEBUG | RW | 0x00 | Memory Window调试接口 |

## 5. 数据包格式

### 5.1 命令包格式

| Byte Index | Field | 说明 |
|------------|-------|------|
| 0 | START | 固定为0xA5 |
| 1 | SEQ | 序列标识符 |
| 2 | CMD | 命令操作码 |
| 3 | LEN | Payload长度 |
| 4..N | PAYLOAD | 命令特定数据 |
| N+1 | CRC | CRC-8校验 |
| N+2 | END | 固定为0x5A |

### 5.2 响应包格式

| Byte Index | Field | 说明 |
|------------|-------|------|
| 0 | START | 固定为0xC3 |
| 1 | SEQ_ECHO | 序列标识符回显 |
| 2 | CMD_ECHO | 命令操作码回显 |
| 3 | STATUS | 响应状态码 |
| 4 | LEN | Payload长度 |
| 5..N | PAYLOAD | 响应数据 |
| N+1 | CRC | CRC-8校验 |
| N+2 | END | 固定为0x3C |

### 5.3 CRC-8定义

- 多项式：x^8 + x^2 + x + 1 (0x07)
- 初始值：0x00
- 不使用反射
- 不使用final XOR
- 按byte更新，每个byte内按MSB first处理

## 6. 设计约束

- 全部内部逻辑位于单一clk时钟域
- rst_n为同步低有效复位
- UART使用8 data bits、no parity、1 stop bit
- FIFO_DEPTH至少为MAX_PAYLOAD_BYTES + 8
- 本版本不需要CDC逻辑

## 7. 文件清单

```
Uart_Controller/rtl/src/
├── uart_packet_controller.sv   # 顶层模块
├── apb_lite_slave.sv           # APB-Lite从接口
├── baud_tick_gen.sv            # 波特率生成器
├── uart_rx.sv                  # UART接收器
├── uart_tx.sv                  # UART发送器
├── byte_fifo.sv                # 同步FIFO
├── crc8_stream.sv              # CRC-8计算
├── packet_parser.sv            # 包解析器
├── command_arbiter.sv          # 命令仲裁器
├── command_engine.sv           # 命令执行引擎
├── reg_file.sv                 # 寄存器文件
├── memory_window.sv            # Memory Window
├── response_builder.sv         # 响应构建器
└── irq_status_ctrl.sv          # 中断状态控制
```

---

文档版本：v1.0
最后更新：2026年5月7日
