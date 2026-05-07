# UART Packet Controller 设计规格说明

## 1. 任务概述

本任务要求设计一个可配置的 UART Packet Controller，用作小型嵌入式外设控制器。该设计同时包含 UART 包接口和 APB-Lite 主机控制接口：控制器从异步 UART RX 输入接收命令包，完成包格式检查、CRC 校验、命令解析，并与 APB 侧调试访问进行共享资源仲裁，最终执行寄存器和内部 memory window 访问操作，再通过 UART TX 返回响应包。

该任务定位为中高难度 RTL 编码 benchmark，用于测试 AI Agent 在复杂 RTL 工程中的模块拆分、接口理解、状态机设计、共享资源仲裁、寄存器副作用处理、协议实现和验证规划能力。设计规模应明显高于简单计数器、电子钟、FIFO 等基础任务，但仍应控制在可通过定向仿真充分验证的范围内。

主要特性如下：

- 全双工 UART 接口，RX 与 TX 数据通路相互独立。
- APB-Lite 主机接口，用于配置、状态读取、计数器读取和 memory window 调试访问。
- 基于单系统时钟生成 UART baud tick 和 oversample tick。
- 命令包格式包含 start byte、sequence byte、command byte、length byte、payload、CRC-8 和 end byte。
- 支持 malformed packet、CRC error、length error、timeout error、UART framing error 等错误检测。
- 支持寄存器读写、memory window 读写、状态读取、FIFO 状态读取、loopback 配置和 soft reset 命令。
- 支持 UART 命令与 APB debug 访问之间的共享寄存器/存储资源仲裁。
- 响应包包含 status code、sequence echo、command echo 和可选 payload。
- 内部包含小型 byte-addressable memory window，用于间接读写和仲裁测试。
- 支持 sticky interrupt source、IRQ mask、read-clear 状态位和外部清除输入。
- 支持 loopback 诊断模式和可编程 FIFO watermark 状态。

## 2. 目标模块列表

实现应包含 14 个逻辑 RTL 模块。允许在模块内部定义小型 function/task 或局部 helper 逻辑，但外部模块图应尽量接近下表，以便后续按模块生成、评审和验证。

| 模块名 | 功能说明 |
|--------|----------|
| `uart_packet_controller` | 顶层集成模块，负责全局连接、reset 处理、状态聚合和顶层输出 |
| `apb_lite_slave` | APB-Lite 从接口前端，接收寄存器和 memory debug 访问请求 |
| `baud_tick_gen` | 根据 `CLK_FREQ_HZ` 和 `BAUD_RATE` 生成 UART bit tick 和 oversample tick |
| `uart_rx` | 实现 UART 8-N-1 接收，将串行输入转换为 byte stream，并检测 framing error |
| `uart_tx` | 实现 UART 8-N-1 发送，从 TX FIFO 取 byte 并串行输出 |
| `byte_fifo` | 参数化同步 FIFO，用于 RX 和 TX byte buffering |
| `crc8_stream` | byte-serial CRC-8 更新/校验模块，供 parser 和 response builder 使用 |
| `packet_parser` | 将 RX byte stream 解析为命令包，完成包格式、长度、timeout 和 CRC 检查 |
| `command_arbiter` | 在 UART command 与 APB debug request 之间仲裁共享寄存器/存储资源 |
| `command_engine` | 执行已解析命令，产生 response descriptor 和状态副作用 |
| `reg_file` | 实现控制/状态寄存器、计数器、read-clear 字段和寄存器副作用 |
| `memory_window` | 实现内部 byte-addressable memory window，并进行地址越界检查 |
| `response_builder` | 根据命令执行结果组装 UART response packet，并写入 TX FIFO |
| `irq_status_ctrl` | 维护 sticky IRQ source、IRQ mask、清除行为和 `irq_o` 生成 |

## 3. 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `CLK_FREQ_HZ` | `50_000_000` | 输入系统时钟频率 |
| `BAUD_RATE` | `115_200` | UART baud rate |
| `OVERSAMPLE` | `16` | UART RX 过采样倍率 |
| `DATA_WIDTH` | `8` | UART byte 宽度，本版本固定为 8 |
| `FIFO_DEPTH` | `32` | RX/TX FIFO 深度，必须为 2 的幂 |
| `MAX_PAYLOAD_BYTES` | `16` | 命令包或响应包最大 payload 字节数 |
| `MEM_ADDR_WIDTH` | `4` | 内部 memory window 地址宽度，默认 16 字节 |
| `APB_ADDR_WIDTH` | `8` | APB byte address 宽度 |
| `APB_DATA_WIDTH` | `32` | APB data 宽度，本版本固定为 32 |
| `TIMEOUT_BITS` | `16` | parser inter-byte timeout 计数器宽度 |
| `INTER_BYTE_TIMEOUT` | `50_000` | 一个包内相邻 byte 之间允许的最大周期数 |

## 4. 顶层接口

### 4.1 输入端口

- `clk`：系统时钟。
- `rst_n`：低有效同步复位。
- `uart_rx_i`：UART 串行接收输入。
- `cfg_enable`：使能 packet parser、命令执行和 response 生成。
- `irq_clear`：单周期脉冲，清除 sticky IRQ source bits。
- `soft_reset_clear`：单周期脉冲，在 firmware 确认后清除 `soft_reset_seen`。
- `paddr[APB_ADDR_WIDTH-1:0]`：APB-Lite byte address。
- `psel`：APB-Lite peripheral select。
- `penable`：APB-Lite access phase 指示。
- `pwrite`：APB-Lite write enable。
- `pwdata[APB_DATA_WIDTH-1:0]`：APB-Lite write data。
- `pstrb[APB_DATA_WIDTH/8-1:0]`：APB-Lite byte write strobe。

### 4.2 输出端口

- `uart_tx_o`：UART 串行发送输出，idle 电平为 1。
- `irq_o`：中断输出，当使能且存在未清除中断源时拉高。
- `busy_o`：当 parser 正在接收包、command engine 正在执行命令或 response 正在发送时拉高。
- `rx_packet_count[15:0]`：已接收并进入执行阶段的有效命令包计数。
- `tx_packet_count[15:0]`：已被 TX 路径接受的 response packet 计数。
- `error_count[15:0]`：parser、command、FIFO、UART 和 APB 错误计数。
- `last_error[3:0]`：最近一次非 OK 状态码的低 4 bit。
- `soft_reset_seen`：执行有效 `SOFT_RESET` 命令后置位的 sticky flag。
- `prdata[APB_DATA_WIDTH-1:0]`：APB-Lite read data。
- `pready`：APB-Lite ready；当共享资源冲突时允许插入 wait state。
- `pslverr`：APB-Lite error response，用于非法地址、非法写入或被拒绝的 debug access。

## 5. Packet 格式

除非特别说明，所有多字节字段均按 most-significant byte first 传输。

### 5.1 Command Packet

| Byte Index | Field | 说明 |
|------------|-------|------|
| 0 | `START` | 固定为 `8'hA5` |
| 1 | `SEQ` | sequence identifier，response 中必须 echo |
| 2 | `CMD` | command opcode |
| 3 | `LEN` | payload 长度，范围 0 到 `MAX_PAYLOAD_BYTES` |
| 4..N | `PAYLOAD` | command-specific payload bytes |
| N+1 | `CRC` | 对 `SEQ`、`CMD`、`LEN` 和 payload 计算的 CRC-8 |
| N+2 | `END` | 固定为 `8'h5A` |

### 5.2 Response Packet

| Byte Index | Field | 说明 |
|------------|-------|------|
| 0 | `START` | 固定为 `8'hC3` |
| 1 | `SEQ_ECHO` | 原始 command packet 的 `SEQ` |
| 2 | `CMD_ECHO` | 原始 command opcode |
| 3 | `STATUS` | response status code |
| 4 | `LEN` | response payload 长度 |
| 5..N | `PAYLOAD` | 可选 response payload |
| N+1 | `CRC` | 对 `SEQ_ECHO`、`CMD_ECHO`、`STATUS`、`LEN` 和 payload 计算的 CRC-8 |
| N+2 | `END` | 固定为 `8'h3C` |

### 5.3 CRC-8 定义

- Polynomial：`x^8 + x^2 + x + 1`，即 `8'h07`。
- Initial value：`8'h00`。
- 不使用 bit reflection。
- 不使用 final XOR。
- CRC 按 byte 更新，每个 byte 内按 MSB first 处理。

## 6. 命令集

| Opcode | 名称 | Request Payload | Response Payload | 说明 |
|--------|------|-----------------|------------------|------|
| `8'h01` | `PING` | none | `8'hAA` | 存活检测 |
| `8'h10` | `REG_READ` | `addr[7:0]` | `data[7:0]` | 读取一个控制/状态寄存器 |
| `8'h11` | `REG_WRITE` | `addr[7:0]`, `data[7:0]` | none | 写入一个可写寄存器 |
| `8'h20` | `MEM_READ` | `addr[7:0]`, `len[7:0]` | memory bytes | 从内部 memory window 读取数据 |
| `8'h21` | `MEM_WRITE` | `addr[7:0]`, data bytes | none | 向内部 memory window 写入一个或多个 byte |
| `8'h30` | `STATUS_READ` | none | status bytes | 返回紧凑状态信息 |
| `8'h31` | `FIFO_STATUS` | none | FIFO status bytes | 返回 RX/TX FIFO level 和 watermark 状态 |
| `8'h40` | `LOOPBACK_CFG` | `enable[0]` | none | 开启或关闭 UART byte loopback 诊断模式 |
| `8'h7E` | `SOFT_RESET` | `8'hDE`, `8'hAD` | none | 清除内部寄存器和 memory，但保留 counters 和 `soft_reset_seen` |

不支持的 opcode 应产生 `STATUS = 8'h03` 的 response，且不带 payload。

## 7. 状态码和错误码

### 7.1 Response Status Code

| Code | 名称 | 含义 |
|------|------|------|
| `8'h00` | `OK` | 命令执行成功 |
| `8'h01` | `CRC_ERROR` | command packet CRC 不匹配 |
| `8'h02` | `LENGTH_ERROR` | payload 长度非法、超限或 packet end byte 错误 |
| `8'h03` | `UNSUPPORTED_CMD` | opcode 未实现 |
| `8'h04` | `ADDR_ERROR` | 寄存器或 memory 地址越界 |
| `8'h05` | `BUSY_ERROR` | command engine 忙，命令无法接受 |
| `8'h06` | `TIMEOUT_ERROR` | 接收一个包时发生 inter-byte timeout |
| `8'h07` | `FRAMING_ERROR` | UART RX 检测到 stop bit 无效 |
| `8'h08` | `FIFO_ERROR` | RX/TX FIFO 操作无法完成 |
| `8'h09` | `APB_CONFLICT` | APB debug access 与正在执行的 UART command 冲突 |

### 7.2 `last_error[3:0]` 编码

`last_error` 保存最近一次非 OK status code 的低 4 bit。命令成功完成时，`last_error` 保持不变。

## 8. Register Map

`reg_file` 通过 UART `REG_READ` / `REG_WRITE` 命令和 APB-Lite 访问共同暴露寄存器空间。APB 读写为 32-bit aligned transfer；对于可写寄存器，应正确处理 byte enable。

| Address | Name | Access | Reset | 说明 |
|---------|------|--------|-------|------|
| `8'h00` | `CTRL` | RW | `8'h01` | Bit 0: response enable；Bit 1: IRQ enable；Bit 2: parser timeout enable |
| `8'h01` | `IRQ_STATUS` | RC | `8'h00` | Bit 0: command done；Bit 1: error seen；Bit 2: RX overflow；Bit 3: TX overflow；Bit 4: FIFO watermark；Bit 5: APB error/conflict |
| `8'h02` | `IRQ_MASK` | RW | `8'h03` | `IRQ_STATUS[5:0]` 的 interrupt mask |
| `8'h03` | `LAST_STATUS` | RO | `8'h00` | 最近一次 response status code |
| `8'h04` | `RX_COUNT_L` | RO | `8'h00` | valid command count 低字节 |
| `8'h05` | `RX_COUNT_H` | RO | `8'h00` | valid command count 高字节 |
| `8'h06` | `ERR_COUNT_L` | RO | `8'h00` | error count 低字节 |
| `8'h07` | `ERR_COUNT_H` | RO | `8'h00` | error count 高字节 |
| `8'h08` | `TX_COUNT_L` | RO | `8'h00` | response packet count 低字节 |
| `8'h09` | `TX_COUNT_H` | RO | `8'h00` | response packet count 高字节 |
| `8'h0A` | `FIFO_WATERMARK` | RW | `8'h10` | FIFO high watermark threshold |
| `8'h0B` | `LOOPBACK_CTRL` | RW | `8'h00` | Bit 0 开启 diagnostic byte loopback mode |
| `8'h10`-`8'h1F` | `MEM_DEBUG` | RW | `8'h00` | APB-visible memory-window debug bytes，每个地址映射一个 byte |

读取不支持的寄存器地址应返回 `ADDR_ERROR`。写入 read-only 或不支持的地址应返回 `ADDR_ERROR`，且不得修改任何状态。

`IRQ_STATUS` 是 read-clear 寄存器：通过 UART 或 APB 成功读取地址 `8'h01` 后，应清除本次返回的 sticky bits。APB 读取 read-clear 寄存器时，`prdata` 应返回清除前的值。顶层 `irq_clear` 输入也应清除所有 sticky IRQ status bits。

## 9. 功能行为

### 9.1 Reset 行为

- reset 后，`uart_tx_o` 应为 1。
- 无 APB transfer 时，APB 输出应为空闲状态：`pready = 1`、`pslverr = 0`、`prdata = 0`。
- RX FIFO 和 TX FIFO 应为空。
- `packet_parser` 应等待 command `START = 8'hA5`。
- 内部 memory window 中所有 byte 应清零。
- `CTRL` reset 为 `8'h01`，默认开启 response，关闭 IRQ 和 timeout。
- `FIFO_WATERMARK` reset 为 `8'h10`，`LOOPBACK_CTRL` reset 为 `8'h00`。
- packet/error counters 只在外部 reset 时清零，soft reset 不清零 counters。
- `soft_reset_seen` 在外部 reset 后为 0，执行有效 `SOFT_RESET` 命令后置 1。

### 9.2 UART RX 行为

- UART 使用 8 data bits、no parity、1 stop bit。
- RX 应使用 `OVERSAMPLE` tick 在 bit 中心附近采样。
- 只有 stop bit 为 high 时，接收到的 byte 才有效。
- framing error 应报告给 packet parser，并计入 `error_count`。
- 应支持在配置 baud rate 下连续 back-to-back UART frame 接收。

### 9.3 UART TX 行为

- UART TX 使用 8 data bits、no parity、1 stop bit。
- 无待发送 byte 时，TX 输出保持 idle high。
- TX 仅在准备开始新 frame 时从 TX FIFO 请求下一个 byte。
- 一旦 byte 被 TX FIFO 接受，TX 路径不得丢弃该 byte。

### 9.4 Packet Parser 行为

- parser 应忽略 command start byte `8'hA5` 之前的所有噪声 byte。
- 看到 `START` 后，parser 依次捕获 `SEQ`、`CMD`、`LEN`、payload bytes、`CRC` 和 `END`。
- 若 `LEN > MAX_PAYLOAD_BYTES`，parser 应丢弃该 packet，并产生 `LENGTH_ERROR`。
- 若 `END != 8'h5A`，parser 应丢弃该 packet，并产生 `LENGTH_ERROR`。
- 若计算得到的 CRC 与收到的 CRC 不一致，parser 应产生 `CRC_ERROR`；该错误 response 应尽量包含已捕获的 `SEQ` 和 `CMD`，但不得执行命令。
- 若 timeout 使能，并且一个 packet 内相邻 byte 的间隔超过 `INTER_BYTE_TIMEOUT`，parser 应放弃当前 partial packet，并产生 `TIMEOUT_ERROR`。
- 任意 malformed packet 后，parser 必须能恢复到搜索下一个 start byte 的状态。

### 9.5 Command Engine 行为

- `command_engine` 一次只接受一个 decoded packet。
- `command_arbiter` 在一个 valid UART command 被接受后，应优先保证该 UART command 对共享资源的原子访问。
- APB 对普通寄存器的访问可以在 UART command 活跃期间完成；APB 对共享 memory window 的访问必须 wait，或在无法保证原子性的情况下返回 `APB_CONFLICT`。
- 有效 command packet 在命令开始执行后递增 `rx_packet_count`。
- parser validation 失败的 packet 不递增 `rx_packet_count`，但应递增 `error_count`。
- `PING` 返回一个 payload byte：`8'hAA`。
- `REG_READ` 要求 payload 长度正好为 1。
- `REG_WRITE` 要求 payload 长度正好为 2。
- `MEM_READ` 要求 payload 长度正好为 2：start address 和 length。
- `MEM_WRITE` 要求 payload 至少为 2：start address 后跟一个或多个 data bytes。
- memory access 不允许地址回绕。任何越界访问应返回 `ADDR_ERROR`，且不得发生 partial update。
- `STATUS_READ` 返回 6 bytes：`last_status`、`last_error`、`rx_packet_count[7:0]`、`rx_packet_count[15:8]`、`error_count[7:0]`、`error_count[15:8]`。
- `FIFO_STATUS` 返回 4 bytes：RX FIFO level、TX FIFO level、RX high-watermark flag、TX high-watermark flag。
- `LOOPBACK_CFG` 要求 payload 长度正好为 1，并更新 `LOOPBACK_CTRL[0]`。
- `SOFT_RESET` 要求 payload 正好为 `8'hDE, 8'hAD`。该命令清除 writable registers、memory window 和 parser partial state，并置位 `soft_reset_seen`。

### 9.6 APB-Lite 行为

- APB 接口应支持标准两阶段 APB transfer：setup phase 为 `psel = 1 && penable = 0`，access phase 为 `psel = 1 && penable = 1`。
- 仅当 access phase 中请求资源忙时，`pready` 才允许拉低插入 wait state。
- 对非法地址、非法写入、不支持的 byte strobe 或被拒绝的 debug access，`pslverr` 应在完成该 access 的周期拉高一个周期。
- APB 写 read-only register 应完成并返回 `pslverr = 1`，且不得修改状态。
- APB 对 `MEM_DEBUG` 的访问是 byte-oriented。只有 `paddr[1:0]` 指定的 byte lane 会影响 memory byte。
- APB 与 UART 对 counters、IRQ status、`last_status` 的更新必须确定。如果 APB read-clear 与 UART event 同周期发生，则新到达的 UART event 在 clear 后仍应保持 pending。

### 9.7 Response Builder 行为

- 当 `CTRL[0] = 1` 时，每个已解析 command 或 parser error 都应生成一个 response packet。
- 当 `CTRL[0] = 0` 时，命令仍然执行，但 response packet 被抑制。
- response packet 应尽量保留原始 `SEQ` 和 `CMD`。如果 parser error 发生在这些字段捕获之前，则使用 `SEQ_ECHO = 8'h00` 和 `CMD_ECHO = 8'h00`。
- 当完整 response packet 被 TX FIFO 接受后，`tx_packet_count` 递增。
- 如果 TX FIFO 空间不足以容纳完整 response，builder 必须等待，不能输出 partial response packet。

### 9.8 Interrupt 行为

- `IRQ_STATUS[0]`：命令完成时置位，包括非 OK 状态的命令。
- `IRQ_STATUS[1]`：产生任意非 OK status 时置位。
- `IRQ_STATUS[2]`：检测到 RX FIFO overflow 时置位。
- `IRQ_STATUS[3]`：TX FIFO overflow，或 response 无法入队时置位。
- `IRQ_STATUS[4]`：任一 FIFO level 达到或超过 `FIFO_WATERMARK` 时置位。
- `IRQ_STATUS[5]`：APB conflict 或 APB slave error 发生时置位。
- `irq_o = CTRL[1] & |(IRQ_STATUS & IRQ_MASK)`。

### 9.9 Loopback 诊断行为

- 当 `LOOPBACK_CTRL[0] = 1` 时，UART RX 接收到的有效 byte 应在完成正常 RX framing 后进入 TX FIFO，而不进入 packet command 执行路径。
- loopback mode 下不执行 packet command，也不递增 `rx_packet_count`。
- loopback byte 仍受 TX FIFO backpressure 约束。若 loopback 导致 TX overflow，应置位 TX overflow IRQ bit，并递增 `error_count`。

## 10. 设计约束和假设

- 全部内部逻辑位于单一 `clk` 时钟域。
- `rst_n` 为同步低有效复位。
- 当 `cfg_enable = 0` 时，parser 保持 idle，清除 partial packet state，并禁止新的命令执行。UART RX 可以继续反序列化 byte，但这些 byte 不应产生命令副作用。
- FIFO 使用同步读写行为。
- `FIFO_DEPTH` 至少应为 `MAX_PAYLOAD_BYTES + 8`，保证最大 response 可以入队。
- APB 和 UART 逻辑共享同一个 `clk` 和 `rst_n`，本版本不需要 CDC 逻辑。
- 本版本不要求 parity、硬件流控、DMA、AXI 总线接口或多时钟域操作。

## 11. 建议内部接口

具体信号名可以调整，但建议采用以下握手形式，便于模块化实现和验证。

### 11.1 Byte Stream Interface

- `byte_valid` / `byte_ready` / `byte_data[7:0]`
- 当某个上升沿 `byte_valid && byte_ready` 为真时，完成一次 byte transfer。

### 11.2 Decoded Command Interface

- `cmd_valid` / `cmd_ready`
- `cmd_seq[7:0]`
- `cmd_opcode[7:0]`
- `cmd_len[4:0]`
- `cmd_payload[MAX_PAYLOAD_BYTES*8-1:0]`
- `cmd_status[7:0]`，用于 parser-generated error。
- `cmd_from_parser_error`，用于区分 parser error 与可执行 command。

### 11.3 Response Interface

- `rsp_valid` / `rsp_ready`
- `rsp_seq_echo[7:0]`
- `rsp_cmd_echo[7:0]`
- `rsp_status[7:0]`
- `rsp_len[4:0]`
- `rsp_payload[MAX_PAYLOAD_BYTES*8-1:0]`

### 11.4 Shared Register/Memory Request Interface

- `req_valid` / `req_ready`
- `req_source`，用于区分 UART command、APB register access 和 APB memory debug access。
- `req_write`
- `req_addr[7:0]`
- `req_wdata[31:0]`
- `req_wstrb[3:0]`
- `resp_valid`
- `resp_status[7:0]`
- `resp_rdata[31:0]`

## 12. 验证计划

### 12.1 UART 测试

- 验证 reset 后 TX idle high。
- 按配置 baud rate 接收单个 byte。
- 按配置 baud rate 发送单个 byte。
- 检测 stop-bit framing error。
- 支持 back-to-back frame，不丢 byte。
- 验证 loopback mode 下 RX byte 能通过 UART TX 返回，且不执行 packet command。

### 12.2 APB-Lite 测试

- 空闲时完成 aligned APB register read/write，且可 zero-wait-state 完成。
- 对 unsupported address 和 illegal write 返回 `pslverr`。
- 对 writable registers 和 memory debug bytes 正确处理 byte strobe。
- UART command 执行期间访问共享 memory 时，应插入 wait state 或返回确定的 conflict status。
- APB read-clear 与 UART event 同周期发生时，新 UART event 不应被错误清除。

### 12.3 Packet Parser 测试

- 接受带 sequence echo 的有效 zero-payload packet。
- 接受有效 maximum-length payload packet。
- 忽略 `START` 前的噪声 byte。
- 拒绝 invalid length packet。
- 拒绝 invalid end byte packet。
- 拒绝 invalid CRC packet。
- malformed packet 后能正确恢复。
- timeout 使能时触发 inter-byte timeout。

### 12.4 Command 测试

- `PING` 返回 `8'hAA`。
- `REG_READ` 和 `REG_WRITE` 正确访问 writable registers。
- 写 read-only register 返回 `ADDR_ERROR`。
- `MEM_WRITE` 后执行 `MEM_READ`，返回数据应一致。
- out-of-range memory access 返回 `ADDR_ERROR`，且不修改 memory。
- unsupported opcode 返回 `UNSUPPORTED_CMD`。
- `STATUS_READ` 正确报告 counters 和 errors。
- `FIFO_STATUS` 正确报告 FIFO level 和 watermark flags。
- `LOOPBACK_CFG` 正确更新 diagnostic loopback mode。
- `SOFT_RESET` 清除 writable state 和 memory，但保留 counters。

### 12.5 FIFO 和 Backpressure 测试

- RX FIFO 支持 burst 到 `FIFO_DEPTH`。
- RX FIFO overflow 被报告并计数。
- TX response builder 在 TX FIFO 空间不足时等待完整 packet 空间。
- response packet 不得因 TX FIFO 临时满而 partial emit。
- FIFO watermark IRQ 根据 `FIFO_WATERMARK` 和 `IRQ_STATUS` clear behavior 正确置位/清除。

### 12.6 集成测试

- 发送完整 UART command packet，并观察完整 UART response packet。
- 连续执行多个 back-to-back commands。
- 通过 `CTRL[0]` 关闭 response，并验证 command 仍然产生副作用。
- 通过 `CTRL[1]` 和 `IRQ_MASK` 开启 IRQ，并验证 `irq_o` assert/clear 行为。
- 在 partial packet 接收过程中拉低 `cfg_enable`，验证 parser state 被丢弃。
- UART packet 收发期间执行 APB status polling。
- 混合 UART `MEM_WRITE` 和 APB `MEM_DEBUG` access 后，验证 shared memory 内容一致。

## 13. 验收标准

1. RTL 实现包含第 2 节列出的 14 个目标逻辑模块。
2. UART RX 和 TX 在配置 baud rate 下正确实现 8-N-1 framing。
3. APB-Lite read、write、wait state、byte strobe 和 error response 符合第 9.6 节要求。
4. packet parser 能接受合法 packet，并以正确 status code 拒绝 malformed packet。
5. command packet 和 response packet 的 CRC-8 生成/校验均符合第 5.3 节定义。
6. 第 6 节列出的所有 command opcode 均符合 payload、response 和 side-effect 规则。
7. register map side effects、APB access rules、read-clear behavior、counters 和 sticky status bits 均符合规格。
8. response packet 格式正确，包含 sequence echo 和有效 CRC，仅在 `CTRL[0] = 0` 时被抑制。
9. FIFO full、empty、overflow、watermark、loopback 和 backpressure 行为不得破坏 packet 顺序或 payload 数据。
10. `irq_o`、`busy_o`、`last_error`、`soft_reset_seen`、`pready` 和 `pslverr` 在 reset、command、APB access、error 和 clear event 后均符合预期。
11. 混合 UART command execution 与 APB debug access 时，仲裁结果确定，且不会产生 partial memory update。
12. 设计应通过 reset、正常命令流、malformed packet、back-to-back UART traffic、APB access、memory-window access、IRQ behavior、loopback mode、arbitration conflict 和 soft reset 的定向测试。
