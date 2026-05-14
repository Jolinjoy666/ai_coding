// 相关器模块
// 计算C/A码与采样数据的相关值

module correlator (
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    input  logic [7:0]  sample_data,   // 采样数据
    input  logic        sample_valid,  // 采样数据有效
    
    input  logic        ca_code_e,     // 超前C/A码
    input  logic        ca_code_p,     // 基准C/A码
    input  logic        ca_code_l,     // 滞后C/A码
    
    output logic [15:0] corr_value_e,  // 超前相关值
    output logic [15:0] corr_value_p,  // 基准相关值
    output logic [15:0] corr_value_l   // 滞后相关值
);

    // 相关值累加寄存器
    logic [15:0] corr_e_acc, corr_p_acc, corr_l_acc;
    
    // 采样数据符号转换
    // C/A码1 -> -1, C/A码0 -> +1
    logic signed [7:0] sample_signed;
    logic signed [7:0] ca_code_e_signed, ca_code_p_signed, ca_code_l_signed;
    
    // 符号转换
    assign sample_signed = sample_data;
    assign ca_code_e_signed = ca_code_e ? -8'sd1 : 8'sd1;
    assign ca_code_p_signed = ca_code_p ? -8'sd1 : 8'sd1;
    assign ca_code_l_signed = ca_code_l ? -8'sd1 : 8'sd1;
    
    // 相关值计算
    logic signed [15:0] corr_e_mult, corr_p_mult, corr_l_mult;
    
    assign corr_e_mult = sample_signed * ca_code_e_signed;
    assign corr_p_mult = sample_signed * ca_code_p_signed;
    assign corr_l_mult = sample_signed * ca_code_l_signed;
    
    // 相关值累加
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            corr_e_acc <= '0;
            corr_p_acc <= '0;
            corr_l_acc <= '0;
        end else if (sample_valid) begin
            corr_e_acc <= corr_e_acc + corr_e_mult;
            corr_p_acc <= corr_p_acc + corr_p_mult;
            corr_l_acc <= corr_l_acc + corr_l_mult;
        end
    end
    
    // 输出赋值
    assign corr_value_e = corr_e_acc;
    assign corr_value_p = corr_p_acc;
    assign corr_value_l = corr_l_acc;

endmodule