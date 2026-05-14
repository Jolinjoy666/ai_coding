// 跟踪控制器模块
// 控制跟踪过程

module tracking_controller (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic        acquired,      // 捕获完成指示
    input  logic [15:0] corr_value_e,  // 超前相关值
    input  logic [15:0] corr_value_p,  // 基准相关值
    input  logic [15:0] corr_value_l,  // 滞后相关值
    
    input  logic        time_slice_end, // 时间片结束信号
    
    output logic        tracking_state // 跟踪状态
);

    // 跟踪状态定义
    typedef enum logic [1:0] {
        TRACK_IDLE,
        TRACK_LOCKED,
        TRACK_ADJUST
    } track_state_t;
    
    track_state_t current_track_state, next_track_state;
    
    // 跟踪状态机寄存器更新
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_track_state <= TRACK_IDLE;
        end else begin
            current_track_state <= next_track_state;
        end
    end
    
    // 跟踪状态机次态逻辑
    always_comb begin
        next_track_state = current_track_state;
        
        case (current_track_state)
            TRACK_IDLE: begin
                if (acquired) begin
                    next_track_state = TRACK_LOCKED;
                end
            end
            TRACK_LOCKED: begin
                if (time_slice_end) begin
                    // 检查是否需要调整
                    if (corr_value_e > corr_value_p || corr_value_l > corr_value_p) begin
                        next_track_state = TRACK_ADJUST;
                    end
                end
            end
            TRACK_ADJUST: begin
                // 调整完成后返回锁定状态
                next_track_state = TRACK_LOCKED;
            end
        endcase
    end
    
    // 输出赋值
    assign tracking_state = (current_track_state == TRACK_LOCKED);

endmodule