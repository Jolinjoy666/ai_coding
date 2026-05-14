#!/usr/bin/env python3
"""
生成BDS/GPS C/A码捕获与跟踪的波形图
"""

import numpy as np
import matplotlib.pyplot as plt
from analyze_ca_code import CACodeGenerator, SignalProcessor

def generate_waveform_plots():
    """生成波形图"""
    print("生成波形图...")
    
    # 创建信号处理器
    processor = SignalProcessor('/home/hp/cfy/ai_coding/BDS_GPS/spec/data_BDS_GPS.txt')
    samples = processor.load_samples()
    
    # 创建C/A码生成器
    ca_gen = CACodeGenerator()
    
    # 创建图形
    fig, axes = plt.subplots(4, 2, figsize=(15, 16))
    fig.suptitle('BDS/GPS C/A码捕获与跟踪结果', fontsize=16)
    
    # 1. 采样数据波形
    ax1 = axes[0, 0]
    time_ms = np.arange(len(samples)) / 16.368e3  # 转换为ms
    ax1.plot(time_ms[:1000], samples[:1000])
    ax1.set_xlabel('时间 (ms)')
    ax1.set_ylabel('采样值')
    ax1.set_title('采样数据波形（前1ms）')
    ax1.grid(True)
    
    # 2. GPS C/A码（卫星22）
    ax2 = axes[0, 1]
    gps_ca_code = ca_gen.generate_gps_ca_code(22)
    ax2.plot(gps_ca_code[:100])
    ax2.set_xlabel('码片索引')
    ax2.set_ylabel('C/A码值')
    ax2.set_title('GPS C/A码（卫星22，前100个码片）')
    ax2.grid(True)
    
    # 3. GPS相关值（卫星22）
    ax3 = axes[1, 0]
    corr_values = processor.detect_bit_timing(22, 'GPS')
    ax3.plot(corr_values)
    ax3.set_xlabel('时间 (ms)')
    ax3.set_ylabel('相关值')
    ax3.set_title('GPS卫星22相关值')
    ax3.grid(True)
    
    # 4. GPS相关值（卫星13）
    ax4 = axes[1, 1]
    corr_values = processor.detect_bit_timing(13, 'GPS')
    ax4.plot(corr_values)
    ax4.set_xlabel('时间 (ms)')
    ax4.set_ylabel('相关值')
    ax4.set_title('GPS卫星13相关值')
    ax4.grid(True)
    
    # 5. BDS C/A码（卫星4）
    ax5 = axes[2, 0]
    bds_ca_code = ca_gen.generate_bds_ca_code(4)
    ax5.plot(bds_ca_code[:100])
    ax5.set_xlabel('码片索引')
    ax5.set_ylabel('C/A码值')
    ax5.set_title('BDS C/A码（卫星4，前100个码片）')
    ax5.grid(True)
    
    # 6. BDS相关值（卫星4）
    ax6 = axes[2, 1]
    corr_values = processor.detect_bit_timing(4, 'BDS')
    ax6.plot(corr_values)
    ax6.set_xlabel('时间 (ms)')
    ax6.set_ylabel('相关值')
    ax6.set_title('BDS卫星4相关值')
    ax6.grid(True)
    
    # 7. GPS和BDS C/A码对比
    ax7 = axes[3, 0]
    ax7.plot(gps_ca_code[:50], label='GPS SV22')
    ax7.plot(bds_ca_code[:50], label='BDS SV4')
    ax7.set_xlabel('码片索引')
    ax7.set_ylabel('C/A码值')
    ax7.set_title('GPS和BDS C/A码对比（前50个码片）')
    ax7.legend()
    ax7.grid(True)
    
    # 8. 相关峰示意图
    ax8 = axes[3, 1]
    # 生成一个理想的相关峰
    x = np.arange(-50, 51)
    y = np.where(np.abs(x) < 10, 1000 - np.abs(x) * 100, 0)
    ax8.plot(x, y)
    ax8.set_xlabel('码片偏移')
    ax8.set_ylabel('相关值')
    ax8.set_title('C/A码相关峰示意图')
    ax8.grid(True)
    
    plt.tight_layout()
    
    # 保存图形
    output_file = '/home/hp/cfy/ai_coding/BDS_GPS/reports/verification/waveforms.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"波形图已保存到: {output_file}")
    
    plt.close()

def generate_correlation_peak_plot():
    """生成相关峰图"""
    print("生成相关峰图...")
    
    # 创建信号处理器
    processor = SignalProcessor('/home/hp/cfy/ai_coding/BDS_GPS/spec/data_BDS_GPS.txt')
    samples = processor.load_samples()
    
    # 创建C/A码生成器
    ca_gen = CACodeGenerator()
    
    # 取1ms的数据
    ms_samples = int(16.368e6 / 1000)
    samples_1ms = samples[:ms_samples]
    
    # 创建图形
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('C/A码相关峰分析', fontsize=16)
    
    # GPS卫星22相关峰
    ax1 = axes[0, 0]
    gps_ca_code = ca_gen.generate_gps_ca_code(22)
    local_code = np.repeat(gps_ca_code, 16)
    local_code = 1 - 2 * np.array(local_code)
    corr = np.correlate(samples_1ms, local_code, mode='full')
    ax1.plot(corr)
    ax1.set_xlabel('延迟（采样点）')
    ax1.set_ylabel('相关值')
    ax1.set_title('GPS卫星22相关峰')
    ax1.grid(True)
    
    # GPS卫星13相关峰
    ax2 = axes[0, 1]
    gps_ca_code = ca_gen.generate_gps_ca_code(13)
    local_code = np.repeat(gps_ca_code, 16)
    local_code = 1 - 2 * np.array(local_code)
    corr = np.correlate(samples_1ms, local_code, mode='full')
    ax2.plot(corr)
    ax2.set_xlabel('延迟（采样点）')
    ax2.set_ylabel('相关值')
    ax2.set_title('GPS卫星13相关峰')
    ax2.grid(True)
    
    # BDS卫星4相关峰
    ax3 = axes[1, 0]
    bds_ca_code = ca_gen.generate_bds_ca_code(4)
    local_code = np.repeat(bds_ca_code, 8)
    local_code = 1 - 2 * np.array(local_code)
    corr = np.correlate(samples_1ms, local_code, mode='full')
    ax3.plot(corr)
    ax3.set_xlabel('延迟（采样点）')
    ax3.set_ylabel('相关值')
    ax3.set_title('BDS卫星4相关峰')
    ax3.grid(True)
    
    # BDS卫星11相关峰
    ax4 = axes[1, 1]
    bds_ca_code = ca_gen.generate_bds_ca_code(11)
    local_code = np.repeat(bds_ca_code, 8)
    local_code = 1 - 2 * np.array(local_code)
    corr = np.correlate(samples_1ms, local_code, mode='full')
    ax4.plot(corr)
    ax4.set_xlabel('延迟（采样点）')
    ax4.set_ylabel('相关值')
    ax4.set_title('BDS卫星11相关峰')
    ax4.grid(True)
    
    plt.tight_layout()
    
    # 保存图形
    output_file = '/home/hp/cfy/ai_coding/BDS_GPS/reports/verification/correlation_peaks.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"相关峰图已保存到: {output_file}")
    
    plt.close()

def generate_cycle_code_plot():
    """生成5位循环码图"""
    print("生成5位循环码图...")
    
    # 创建信号处理器
    processor = SignalProcessor('/home/hp/cfy/ai_coding/BDS_GPS/spec/data_BDS_GPS.txt')
    processor.load_samples()  # 加载采样数据
    
    # 创建图形
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('5位循环码解调结果', fontsize=16)
    
    # GPS卫星22循环码
    ax1 = axes[0, 0]
    corr_values = processor.detect_bit_timing(22, 'GPS')
    ax1.plot(corr_values[:20])
    ax1.axhline(y=0, color='r', linestyle='--')
    ax1.set_xlabel('时间 (ms)')
    ax1.set_ylabel('相关值')
    ax1.set_title('GPS卫星22相关值（前20ms）')
    ax1.grid(True)
    
    # GPS卫星13循环码
    ax2 = axes[0, 1]
    corr_values = processor.detect_bit_timing(13, 'GPS')
    ax2.plot(corr_values[:20])
    ax2.axhline(y=0, color='r', linestyle='--')
    ax2.set_xlabel('时间 (ms)')
    ax2.set_ylabel('相关值')
    ax2.set_title('GPS卫星13相关值（前20ms）')
    ax2.grid(True)
    
    # BDS卫星4循环码
    ax3 = axes[1, 0]
    corr_values = processor.detect_bit_timing(4, 'BDS')
    ax3.plot(corr_values[:20])
    ax3.axhline(y=0, color='r', linestyle='--')
    ax3.set_xlabel('时间 (ms)')
    ax3.set_ylabel('相关值')
    ax3.set_title('BDS卫星4相关值（前20ms）')
    ax3.grid(True)
    
    # BDS卫星11循环码
    ax4 = axes[1, 1]
    corr_values = processor.detect_bit_timing(11, 'BDS')
    ax4.plot(corr_values[:20])
    ax4.axhline(y=0, color='r', linestyle='--')
    ax4.set_xlabel('时间 (ms)')
    ax4.set_ylabel('相关值')
    ax4.set_title('BDS卫星11相关值（前20ms）')
    ax4.grid(True)
    
    plt.tight_layout()
    
    # 保存图形
    output_file = '/home/hp/cfy/ai_coding/BDS_GPS/reports/verification/cycle_codes.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"循环码图已保存到: {output_file}")
    
    plt.close()

def main():
    """主函数"""
    print("=" * 60)
    print("生成BDS/GPS C/A码捕获与跟踪波形图")
    print("=" * 60)
    
    # 生成波形图
    generate_waveform_plots()
    
    # 生成相关峰图
    generate_correlation_peak_plot()
    
    # 生成循环码图
    generate_cycle_code_plot()
    
    print("\n所有波形图生成完成！")

if __name__ == '__main__':
    main()