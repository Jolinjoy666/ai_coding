// BDS_GPS 测试平台
// 基本测试平台，用于验证BDS_GPS顶层模块

module tb_bds_gps_top;

    // 时钟和复位
    reg clk;
    reg rst_n;
    
    // 采样数据输入
    reg [7:0] sample_data;
    reg sample_valid;
    
    // 输出接口
    wire [5:0] satellite_num;
    wire [4:0] cycle_code;
    wire acquisition_done;
    wire tracking_locked;
    
    // 时钟周期定义
    parameter CLK_PERIOD = 61.08; // 16.368MHz -> 61.08ns
    
    // 实例化被测模块
    bds_gps_top u_bds_gps_top (
        .clk(clk),
        .rst_n(rst_n),
        .sample_data(sample_data),
        .sample_valid(sample_valid),
        .satellite_num(satellite_num),
        .cycle_code(cycle_code),
        .acquisition_done(acquisition_done),
        .tracking_locked(tracking_locked)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 测试序列
    initial begin
        // 初始化
        rst_n = 0;
        sample_data = 0;
        sample_valid = 0;
        
        // 复位
        #100;
        rst_n = 1;
        
        // 等待复位完成
        #100;
        
        // 测试1：基本功能测试
        $display("Test 1: Basic functionality test");
        sample_valid = 1;
        sample_data = 8'h01;
        #1000;
        
        // 测试2：采样数据变化
        $display("Test 2: Sample data variation test");
        sample_data = 8'h02;
        #1000;
        
        // 测试3：等待捕获
        $display("Test 3: Wait for acquisition");
        #10000;
        
        // 测试4：检查输出
        $display("Test 4: Check output");
        $display("Satellite num: %d", satellite_num);
        $display("Cycle code: %b", cycle_code);
        $display("Acquisition done: %b", acquisition_done);
        $display("Tracking locked: %b", tracking_locked);
        
        // 结束测试
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // 波形输出
    initial begin
        $dumpfile("tb_bds_gps_top.vcd");
        $dumpvars(0, tb_bds_gps_top);
    end

endmodule