// 捕获检测器模块
// 检测捕获状态

module acquisition_detector (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic [31:0] accum_result,  // 累加结果
    input  logic        time_slice_end, // 时间片结束信号
    
    output logic        acquired,      // 捕获完成指示
    output logic        threshold_exceeded // 阈值超出指示
);

    // 捕获阈值参数
    localparam ACQUISITION_THRESHOLD = 32'd1000; // 示例阈值，实际需要根据系统调整
    
    // 捕获状态寄存器
    logic acquired_reg;
    
    // 捕获检测逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acquired_reg <= 1'b0;
        end else if (time_slice_end) begin
            // 时间片结束时检查是否捕获
            if (accum_result > ACQUISITION_THRESHOLD) begin
                acquired_reg <= 1'b1;
            end else begin
                acquired_reg <= 1'b0;
            end
        end
    end
    
    // 输出赋值
    assign acquired = acquired_reg;
    assign threshold_exceeded = (accum_result > ACQUISITION_THRESHOLD);

endmodule