// C/A码生成器模块
// 生成GPS和BDS的C/A码

module ca_code_generator (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic [1:0]  time_slice_id, // 时间片ID
    output logic        ca_code_e,     // 超前C/A码
    output logic        ca_code_p,     // 基准C/A码
    output logic        ca_code_l,     // 滞后C/A码
    output logic [9:0]  gps_ca_code,   // GPS C/A码（10位）
    output logic [10:0] bds_ca_code    // BDS C/A码（11位）
);

    // GPS C/A码参数
    localparam GPS_REG_WIDTH = 10;
    localparam GPS_CA_PERIOD = 1023;
    
    // BDS C/A码参数
    localparam BDS_REG_WIDTH = 11;
    localparam BDS_CA_PERIOD = 2046;
    
    // GPS C/A码寄存器
    logic [GPS_REG_WIDTH-1:0] gps_g1_reg, gps_g2_reg;
    logic gps_g1_feedback, gps_g2_feedback;
    logic gps_g1_output, gps_g2_output;
    
    // BDS C/A码寄存器
    logic [BDS_REG_WIDTH-1:0] bds_g1_reg, bds_g2_reg;
    logic bds_g1_feedback, bds_g2_feedback;
    logic bds_g1_output, bds_g2_output;
    
    // 相位延迟寄存器（用于e、p、l三路）
    logic ca_code_p_reg;
    logic ca_code_e_reg, ca_code_l_reg;
    
    // GPS G1反馈逻辑
    assign gps_g1_feedback = gps_g1_reg[9] ^ gps_g1_reg[2]; // D3和D10的模2加
    
    // GPS G2反馈逻辑
    assign gps_g2_feedback = gps_g2_reg[9] ^ gps_g2_reg[8] ^ gps_g2_reg[5] ^ 
                             gps_g2_reg[3] ^ gps_g2_reg[2] ^ gps_g2_reg[1]; // D2、D3、D6、D8、D9和D10
    
    // GPS G1输出
    assign gps_g1_output = gps_g1_reg[9]; // D10
    
    // GPS G2输出（需要根据卫星号选择两个寄存器）
    // 这里简化处理，实际需要根据sv_num选择
    assign gps_g2_output = gps_g2_reg[9] ^ gps_g2_reg[8]; // 示例：选择D10和D9
    
    // GPS C/A码输出
    assign gps_ca_code = gps_g1_reg;
    
    // BDS G1反馈逻辑
    assign bds_g1_feedback = bds_g1_reg[10] ^ bds_g1_reg[6] ^ bds_g1_reg[5] ^ 
                             bds_g1_reg[4] ^ bds_g1_reg[0]; // D1、D7、D8、D9和D11
    
    // BDS G2反馈逻辑
    assign bds_g2_feedback = bds_g2_reg[10] ^ bds_g2_reg[9] ^ bds_g2_reg[8] ^ 
                             bds_g2_reg[7] ^ bds_g2_reg[6] ^ bds_g2_reg[3] ^ 
                             bds_g2_reg[2] ^ bds_g2_reg[0]; // D1、D2、D3、D4、D5、D8、D9和D11
    
    // BDS G1输出
    assign bds_g1_output = bds_g1_reg[10]; // D11
    
    // BDS G2输出（需要根据卫星号选择两个寄存器）
    // 这里简化处理，实际需要根据sv_num选择
    assign bds_g2_output = bds_g2_reg[10] ^ bds_g2_reg[9]; // 示例：选择D11和D10
    
    // BDS C/A码输出
    assign bds_ca_code = bds_g1_reg;
    
    // GPS C/A码生成逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gps_g1_reg <= {GPS_REG_WIDTH{1'b1}}; // 全1
            gps_g2_reg <= {GPS_REG_WIDTH{1'b1}}; // 全1
        end else begin
            // G1移位寄存器
            gps_g1_reg <= {gps_g1_reg[GPS_REG_WIDTH-2:0], gps_g1_feedback};
            
            // G2移位寄存器
            gps_g2_reg <= {gps_g2_reg[GPS_REG_WIDTH-2:0], gps_g2_feedback};
        end
    end
    
    // BDS C/A码生成逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bds_g1_reg <= 11'b01010101010; // 起始相位
            bds_g2_reg <= 11'b01010101010; // 起始相位
        end else begin
            // G1移位寄存器
            bds_g1_reg <= {bds_g1_reg[BDS_REG_WIDTH-2:0], bds_g1_feedback};
            
            // G2移位寄存器
            bds_g2_reg <= {bds_g2_reg[BDS_REG_WIDTH-2:0], bds_g2_feedback};
        end
    end
    
    // C/A码输出选择
    logic ca_code_out;
    always_comb begin
        case (time_slice_id)
            2'b00, 2'b01: begin // GPS卫星
                ca_code_out = gps_g1_output ^ gps_g2_output;
            end
            2'b10, 2'b11: begin // BDS卫星
                ca_code_out = bds_g1_output ^ bds_g2_output;
            end
        endcase
    end
    
    // 相位延迟逻辑（用于e、p、l三路）
    // GPS：超前和滞后4个系统时钟周期
    // BDS：超前和滞后2个系统时钟周期
    logic [3:0] delay_counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_counter <= '0;
            ca_code_p_reg <= '0;
            ca_code_e_reg <= '0;
            ca_code_l_reg <= '0;
        end else begin
            delay_counter <= delay_counter + 1'b1;
            
            // 基准C/A码
            ca_code_p_reg <= ca_code_out;
            
            // 超前C/A码（相位超前）
            case (time_slice_id)
                2'b00, 2'b01: begin // GPS：超前4个时钟周期
                    if (delay_counter == 4) begin
                        ca_code_e_reg <= ca_code_out;
                    end
                end
                2'b10, 2'b11: begin // BDS：超前2个时钟周期
                    if (delay_counter == 2) begin
                        ca_code_e_reg <= ca_code_out;
                    end
                end
            endcase
            
            // 滞后C/A码（相位滞后）
            case (time_slice_id)
                2'b00, 2'b01: begin // GPS：滞后4个时钟周期
                    if (delay_counter == 12) begin // 16-4=12
                        ca_code_l_reg <= ca_code_out;
                    end
                end
                2'b10, 2'b11: begin // BDS：滞后2个时钟周期
                    if (delay_counter == 6) begin // 8-2=6
                        ca_code_l_reg <= ca_code_out;
                    end
                end
            endcase
        end
    end
    
    // 输出赋值
    assign ca_code_e = ca_code_e_reg;
    assign ca_code_p = ca_code_p_reg;
    assign ca_code_l = ca_code_l_reg;

endmodule