// 时间片调度器模块
// 管理时间片调度，控制卫星处理顺序

module time_slice_scheduler (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    output logic [1:0]  time_slice_id, // 时间片ID（00: GPS1, 01: GPS2, 10: BDS1, 11: BDS2）
    output logic        time_slice_start, // 时间片开始信号
    output logic        time_slice_end    // 时间片结束信号
);

    // 时间片参数
    localparam TIME_SLICE_COUNTS = 16368; // 1ms时间片（16.368MHz * 1ms）
    localparam SATELLITE_NUM = 4;
    
    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,
        SLICE_START,
        PROCESSING,
        SLICE_END
    } state_t;
    
    state_t current_state, next_state;
    
    // 计数器
    logic [15:0] slice_counter;
    logic [1:0] satellite_index;
    
    // 状态机寄存器更新
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            slice_counter <= '0;
            satellite_index <= '0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    slice_counter <= '0;
                end
                SLICE_START: begin
                    slice_counter <= '0;
                end
                PROCESSING: begin
                    slice_counter <= slice_counter + 1'b1;
                end
                SLICE_END: begin
                    if (satellite_index == SATELLITE_NUM - 1) begin
                        satellite_index <= '0;
                    end else begin
                        satellite_index <= satellite_index + 1'b1;
                    end
                end
            endcase
        end
    end
    
    // 状态机次态逻辑
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                next_state = SLICE_START;
            end
            SLICE_START: begin
                next_state = PROCESSING;
            end
            PROCESSING: begin
                if (slice_counter == TIME_SLICE_COUNTS - 1) begin
                    next_state = SLICE_END;
                end
            end
            SLICE_END: begin
                next_state = SLICE_START;
            end
        endcase
    end
    
    // 输出逻辑
    assign time_slice_id = satellite_index;
    assign time_slice_start = (current_state == SLICE_START);
    assign time_slice_end = (current_state == SLICE_END);

endmodule