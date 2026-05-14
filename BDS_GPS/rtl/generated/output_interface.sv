// 输出接口模块
// 输出卫星号和5位循环码

module output_interface (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic [1:0]  time_slice_id, // 时间片ID
    input  logic        acquired,      // 捕获完成指示
    input  logic        tracking_state, // 跟踪状态
    input  logic [31:0] accum_result,  // 累加结果
    
    output logic [5:0]  satellite_num, // 卫星号（sv_num）
    output logic [4:0]  cycle_code,    // 5位循环码
    output logic        acquisition_done, // 捕获完成指示
    output logic        tracking_locked   // 跟踪锁定指示
);

    // 卫星号映射
    // 根据时间片ID映射到卫星号
    // 这里简化处理，实际需要根据sv_num映射表
    always_comb begin
        case (time_slice_id)
            2'b00: satellite_num = 6'd1;  // GPS卫星1
            2'b01: satellite_num = 6'd2;  // GPS卫星2
            2'b10: satellite_num = 6'd31; // BDS卫星1
            2'b11: satellite_num = 6'd32; // BDS卫星2
            default: satellite_num = '0;
        endcase
    end
    
    // 5位循环码解调
    // 这里简化处理，实际需要根据相关值正负关系解调
    logic [4:0] cycle_code_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_code_reg <= '0;
        end else if (tracking_state && acquired) begin
            // 根据相关值正负关系解调5位循环码
            // 这里简化处理，实际需要更复杂的逻辑
            if (accum_result[31] == 1'b0) begin // 正相关值
                cycle_code_reg <= {cycle_code_reg[3:0], 1'b0};
            end else begin // 负相关值
                cycle_code_reg <= {cycle_code_reg[3:0], 1'b1};
            end
        end
    end
    
    // 输出赋值
    assign cycle_code = cycle_code_reg;
    assign acquisition_done = acquired;
    assign tracking_locked = tracking_state;

endmodule