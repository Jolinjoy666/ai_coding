// BDS_GPS Top Module
// BDS/GPS卫星导航系统C/A码捕获与跟踪顶层模块

module bds_gps_top (
    // 时钟和复位
    input  logic        clk,           // 16.368MHz系统时钟
    input  logic        rst_n,         // 异步复位，低有效
    
    // 采样数据输入
    input  logic [7:0]  sample_data,   // 采样数据
    input  logic        sample_valid,  // 采样数据有效
    
    // 输出接口
    output logic [5:0]  satellite_num, // 卫星号（sv_num）
    output logic [4:0]  cycle_code,    // 5位循环码
    output logic        acquisition_done, // 捕获完成指示
    output logic        tracking_locked   // 跟踪锁定指示
);

    // 时间片调度信号
    logic [1:0] time_slice_id;
    logic time_slice_start;
    logic time_slice_end;
    
    // C/A码生成信号
    logic ca_code_e, ca_code_p, ca_code_l;
    logic [9:0] gps_ca_code;
    logic [10:0] bds_ca_code;
    
    // 相关值信号
    logic [15:0] corr_value_e, corr_value_p, corr_value_l;
    
    // 累加结果
    logic [31:0] accum_result;
    
    // 捕获状态
    logic acquired;
    logic threshold_exceeded;
    
    // 跟踪状态
    logic tracking_state;
    
    // 时间片调度器
    time_slice_scheduler u_time_slice_scheduler (
        .clk(clk),
        .rst_n(rst_n),
        .time_slice_id(time_slice_id),
        .time_slice_start(time_slice_start),
        .time_slice_end(time_slice_end)
    );
    
    // C/A码生成器
    ca_code_generator u_ca_code_generator (
        .clk(clk),
        .rst_n(rst_n),
        .time_slice_id(time_slice_id),
        .ca_code_e(ca_code_e),
        .ca_code_p(ca_code_p),
        .ca_code_l(ca_code_l),
        .gps_ca_code(gps_ca_code),
        .bds_ca_code(bds_ca_code)
    );
    
    // 相关器
    correlator u_correlator (
        .clk(clk),
        .rst_n(rst_n),
        .sample_data(sample_data),
        .sample_valid(sample_valid),
        .ca_code_e(ca_code_e),
        .ca_code_p(ca_code_p),
        .ca_code_l(ca_code_l),
        .corr_value_e(corr_value_e),
        .corr_value_p(corr_value_p),
        .corr_value_l(corr_value_l)
    );
    
    // 累加器
    accumulator u_accumulator (
        .clk(clk),
        .rst_n(rst_n),
        .corr_value_e(corr_value_e),
        .corr_value_p(corr_value_p),
        .corr_value_l(corr_value_l),
        .time_slice_end(time_slice_end),
        .accum_result(accum_result)
    );
    
    // 捕获检测器
    acquisition_detector u_acquisition_detector (
        .clk(clk),
        .rst_n(rst_n),
        .accum_result(accum_result),
        .time_slice_end(time_slice_end),
        .acquired(acquired),
        .threshold_exceeded(threshold_exceeded)
    );
    
    // 跟踪控制器
    tracking_controller u_tracking_controller (
        .clk(clk),
        .rst_n(rst_n),
        .acquired(acquired),
        .corr_value_e(corr_value_e),
        .corr_value_p(corr_value_p),
        .corr_value_l(corr_value_l),
        .time_slice_end(time_slice_end),
        .tracking_state(tracking_state)
    );
    
    // 输出接口
    output_interface u_output_interface (
        .clk(clk),
        .rst_n(rst_n),
        .time_slice_id(time_slice_id),
        .acquired(acquired),
        .tracking_state(tracking_state),
        .accum_result(accum_result),
        .satellite_num(satellite_num),
        .cycle_code(cycle_code),
        .acquisition_done(acquisition_done),
        .tracking_locked(tracking_locked)
    );

endmodule