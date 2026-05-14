// 累加器模块
// 累加相关值（1ms周期）

module accumulator (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic [15:0] corr_value_e,  // 超前相关值
    input  logic [15:0] corr_value_p,  // 基准相关值
    input  logic [15:0] corr_value_l,  // 滞后相关值
    
    input  logic        time_slice_end, // 时间片结束信号
    
    output logic [31:0] accum_result   // 累加结果
);

    // 累加寄存器
    logic [31:0] accum_e, accum_p, accum_l;
    
    // 累加逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_e <= '0;
            accum_p <= '0;
            accum_l <= '0;
        end else if (time_slice_end) begin
            // 时间片结束时清零累加器
            accum_e <= '0;
            accum_p <= '0;
            accum_l <= '0;
        end else begin
            // 累加相关值
            accum_e <= accum_e + corr_value_e;
            accum_p <= accum_p + corr_value_p;
            accum_l <= accum_l + corr_value_l;
        end
    end
    
    // 输出累加结果（这里简化处理，实际可能需要更复杂的逻辑）
    assign accum_result = accum_p;

endmodule