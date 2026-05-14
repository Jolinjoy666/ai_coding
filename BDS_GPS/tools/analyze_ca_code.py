#!/usr/bin/env python3
"""
BDS/GPS C/A码捕获与跟踪分析脚本
从采样文件中捕获卫星C/A码，识别卫星号，解调5位循环码
"""

import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

class CACodeGenerator:
    """C/A码生成器"""
    
    def __init__(self):
        # GPS C/A码参数
        self.gps_reg_width = 10
        self.gps_ca_period = 1023
        
        # BDS C/A码参数
        self.bds_reg_width = 11
        self.bds_ca_period = 2046
        
        # GPS G2寄存器选择表（sv_num -> 两个寄存器位置）
        self.gps_g2_table = {
            1: (2, 6), 2: (3, 7), 3: (4, 8), 4: (5, 9), 5: (1, 9),
            6: (2, 10), 7: (1, 8), 8: (2, 9), 9: (3, 10), 10: (2, 3),
            11: (3, 4), 12: (5, 6), 13: (6, 7), 14: (7, 8), 15: (8, 9),
            16: (9, 10), 17: (1, 4), 18: (2, 5), 19: (3, 6), 20: (4, 7),
            21: (5, 8), 22: (6, 9), 23: (1, 3), 24: (4, 6), 25: (5, 7),
            26: (6, 8), 27: (7, 9), 28: (8, 10), 29: (1, 6), 30: (2, 7),
            31: (3, 8), 32: (4, 9)
        }
        
        # BDS G2寄存器选择表（sv_num -> 两个寄存器位置）
        self.bds_g2_table = {
            1: (1, 5), 2: (1, 6), 3: (1, 7), 4: (1, 8), 5: (1, 9),
            6: (1, 10), 7: (1, 11), 8: (2, 6), 9: (2, 7), 10: (2, 8),
            11: (2, 9), 12: (2, 10), 13: (2, 11), 14: (3, 6), 15: (3, 7),
            16: (3, 8), 17: (3, 9), 18: (3, 10), 19: (3, 11), 20: (4, 6),
            21: (4, 7), 22: (4, 8), 23: (4, 9), 24: (4, 10), 25: (4, 11),
            26: (5, 6), 27: (5, 7), 28: (5, 8), 29: (5, 9), 30: (5, 10),
            31: (5, 11), 32: (6, 7), 33: (6, 8), 34: (6, 9), 35: (6, 10),
            36: (6, 11), 37: (7, 8), 38: (7, 9), 39: (7, 10), 40: (7, 11),
            41: (8, 9), 42: (8, 10), 43: (8, 11), 44: (9, 10), 45: (9, 11),
            46: (10, 11)
        }
    
    def generate_gps_ca_code(self, sv_num):
        """生成GPS C/A码"""
        # 初始化寄存器
        g1_reg = [1] * self.gps_reg_width
        g2_reg = [1] * self.gps_reg_width
        
        # 获取G2寄存器选择
        g2_sel1, g2_sel2 = self.gps_g2_table[sv_num]
        
        ca_code = []
        
        for _ in range(self.gps_ca_period):
            # G1反馈：D3和D10
            g1_feedback = g1_reg[2] ^ g1_reg[9]
            
            # G2反馈：D2、D3、D6、D8、D9和D10
            g2_feedback = g2_reg[1] ^ g2_reg[2] ^ g2_reg[5] ^ g2_reg[7] ^ g2_reg[8] ^ g2_reg[9]
            
            # G1输出
            g1_output = g1_reg[9]
            
            # G2输出
            g2_output = g2_reg[g2_sel1-1] ^ g2_reg[g2_sel2-1]
            
            # C/A码输出
            ca_code.append(g1_output ^ g2_output)
            
            # 移位
            g1_reg = [g1_feedback] + g1_reg[:-1]
            g2_reg = [g2_feedback] + g2_reg[:-1]
        
        return ca_code
    
    def generate_bds_ca_code(self, sv_num):
        """生成BDS C/A码"""
        # 初始化寄存器
        g1_reg = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]  # 01010101010
        g2_reg = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]  # 01010101010
        
        # 获取G2寄存器选择
        g2_sel1, g2_sel2 = self.bds_g2_table[sv_num]
        
        ca_code = []
        
        for _ in range(self.bds_ca_period):
            # G1反馈：D1、D7、D8、D9和D11
            g1_feedback = g1_reg[0] ^ g1_reg[6] ^ g1_reg[7] ^ g1_reg[8] ^ g1_reg[10]
            
            # G2反馈：D1、D2、D3、D4、D5、D8、D9和D11
            g2_feedback = g2_reg[0] ^ g2_reg[1] ^ g2_reg[2] ^ g2_reg[3] ^ g2_reg[4] ^ g2_reg[7] ^ g2_reg[8] ^ g2_reg[10]
            
            # G1输出
            g1_output = g1_reg[10]
            
            # G2输出
            g2_output = g2_reg[g2_sel1-1] ^ g2_reg[g2_sel2-1]
            
            # C/A码输出
            ca_code.append(g1_output ^ g2_output)
            
            # 移位
            g1_reg = [g1_feedback] + g1_reg[:-1]
            g2_reg = [g2_feedback] + g2_reg[:-1]
        
        return ca_code


class SignalProcessor:
    """信号处理器"""
    
    def __init__(self, sample_file):
        self.sample_file = sample_file
        self.samples = None
        self.fs = 16.368e6  # 采样频率
        self.gps_chip_rate = 1.023e6  # GPS C/A码片速率
        self.bds_chip_rate = 2.046e6  # BDS C/A码片速率
        self.gps_chip_samples = 16  # GPS每个码片采样数
        self.bds_chip_samples = 8   # BDS每个码片采样数
    
    def load_samples(self):
        """加载采样数据"""
        print(f"Loading samples from {self.sample_file}...")
        
        with open(self.sample_file, 'r') as f:
            lines = f.readlines()
        
        # 解析4位二进制数据
        samples = []
        for line in lines:
            line = line.strip()
            if line:
                # 将4位二进制转换为十进制（有符号）
                value = int(line, 2)
                # 转换为有符号数（最高位为符号位）
                if value >= 8:
                    value = value - 16
                samples.append(value)
        
        self.samples = np.array(samples)
        print(f"Loaded {len(self.samples)} samples")
        print(f"Sample rate: {self.fs/1e6} MHz")
        print(f"Duration: {len(self.samples)/self.fs*1000:.2f} ms")
        
        return self.samples
    
    def correlate_ca_code(self, samples, ca_code, chip_samples):
        """计算C/A码相关值"""
        # 生成本地C/A码信号（每个码片重复chip_samples次）
        local_code = np.repeat(ca_code, chip_samples)
        
        # 转换为+1/-1
        local_code = 1 - 2 * np.array(local_code)
        
        # 计算相关值
        corr = np.correlate(samples, local_code, mode='full')
        
        return corr
    
    def find_satellites(self, system='GPS'):
        """查找卫星"""
        ca_gen = CACodeGenerator()
        
        if system == 'GPS':
            sv_range = range(1, 33)  # GPS卫星号1-32
            chip_samples = self.gps_chip_samples
            ca_period = 1023
        else:  # BDS
            sv_range = range(1, 47)  # BDS卫星号1-46
            chip_samples = self.bds_chip_samples
            ca_period = 2046
        
        # 取1ms的数据进行分析
        ms_samples = int(self.fs / 1000)  # 1ms的采样数
        samples_1ms = self.samples[:ms_samples]
        
        results = {}
        
        for sv_num in sv_range:
            # 生成C/A码
            if system == 'GPS':
                ca_code = ca_gen.generate_gps_ca_code(sv_num)
            else:
                ca_code = ca_gen.generate_bds_ca_code(sv_num)
            
            # 计算相关值
            corr = self.correlate_ca_code(samples_1ms, ca_code, chip_samples)
            
            # 找到最大相关值
            max_corr = np.max(np.abs(corr))
            max_idx = np.argmax(np.abs(corr))
            
            # 计算阈值（最大值的50%）
            threshold = max_corr * 0.5
            
            # 检查是否超过阈值
            if max_corr > threshold:
                results[sv_num] = {
                    'max_corr': max_corr,
                    'max_idx': max_idx,
                    'threshold': threshold
                }
        
        return results
    
    def detect_bit_timing(self, sv_num, system='GPS'):
        """检测比特定时"""
        ca_gen = CACodeGenerator()
        
        if system == 'GPS':
            ca_code = ca_gen.generate_gps_ca_code(sv_num)
            chip_samples = self.gps_chip_samples
        else:
            ca_code = ca_gen.generate_bds_ca_code(sv_num)
            chip_samples = self.bds_chip_samples
        
        # 生成本地C/A码信号
        local_code = np.repeat(ca_code, chip_samples)
        local_code = 1 - 2 * np.array(local_code)
        
        # 计算每个1ms周期的相关值
        ms_samples = int(self.fs / 1000)
        num_ms = len(self.samples) // ms_samples
        
        corr_values = []
        for i in range(num_ms):
            start = i * ms_samples
            end = start + ms_samples
            if end <= len(self.samples):
                corr = np.sum(self.samples[start:end] * local_code[:ms_samples])
                corr_values.append(corr)
        
        return np.array(corr_values)
    
    def extract_cycle_code(self, corr_values, num_bits=5):
        """提取5位循环码"""
        # 根据相关值的正负判断比特
        bits = []
        for corr in corr_values:
            if corr > 0:
                bits.append(0)
            else:
                bits.append(1)
        
        # 提取前num_bits个比特作为循环码
        cycle_code = bits[:num_bits]
        
        return cycle_code


def main():
    """主函数"""
    print("=" * 60)
    print("BDS/GPS C/A码捕获与跟踪分析")
    print("=" * 60)
    
    # 创建信号处理器
    processor = SignalProcessor('/home/hp/cfy/ai_coding/BDS_GPS/spec/data_BDS_GPS.txt')
    
    # 加载采样数据
    samples = processor.load_samples()
    
    # 查找GPS卫星
    print("\n" + "=" * 60)
    print("查找GPS卫星...")
    print("=" * 60)
    gps_results = processor.find_satellites('GPS')
    
    if gps_results:
        print(f"\n找到 {len(gps_results)} 颗GPS卫星:")
        for sv_num, result in sorted(gps_results.items(), key=lambda x: x[1]['max_corr'], reverse=True):
            print(f"  GPS SV {sv_num:2d}: 最大相关值 = {result['max_corr']:.0f}")
    else:
        print("未找到GPS卫星")
    
    # 查找BDS卫星
    print("\n" + "=" * 60)
    print("查找BDS卫星...")
    print("=" * 60)
    bds_results = processor.find_satellites('BDS')
    
    if bds_results:
        print(f"\n找到 {len(bds_results)} 颗BDS卫星:")
        for sv_num, result in sorted(bds_results.items(), key=lambda x: x[1]['max_corr'], reverse=True):
            print(f"  BDS SV {sv_num:2d}: 最大相关值 = {result['max_corr']:.0f}")
    else:
        print("未找到BDS卫星")
    
    # 提取前两颗GPS卫星的5位循环码
    print("\n" + "=" * 60)
    print("提取GPS卫星5位循环码")
    print("=" * 60)
    
    gps_sorted = sorted(gps_results.items(), key=lambda x: x[1]['max_corr'], reverse=True)
    gps_cycle_codes = {}
    
    for i, (sv_num, result) in enumerate(gps_sorted[:2]):
        print(f"\n处理GPS卫星 {sv_num}:")
        corr_values = processor.detect_bit_timing(sv_num, 'GPS')
        cycle_code = processor.extract_cycle_code(corr_values, 5)
        gps_cycle_codes[sv_num] = cycle_code
        print(f"  5位循环码: {cycle_code}")
        print(f"  循环码二进制: {''.join(map(str, cycle_code))}")
    
    # 提取前两颗BDS卫星的5位循环码
    print("\n" + "=" * 60)
    print("提取BDS卫星5位循环码")
    print("=" * 60)
    
    bds_sorted = sorted(bds_results.items(), key=lambda x: x[1]['max_corr'], reverse=True)
    bds_cycle_codes = {}
    
    for i, (sv_num, result) in enumerate(bds_sorted[:2]):
        print(f"\n处理BDS卫星 {sv_num}:")
        corr_values = processor.detect_bit_timing(sv_num, 'BDS')
        cycle_code = processor.extract_cycle_code(corr_values, 5)
        bds_cycle_codes[sv_num] = cycle_code
        print(f"  5位循环码: {cycle_code}")
        print(f"  循环码二进制: {''.join(map(str, cycle_code))}")
    
    # 输出最终结果
    print("\n" + "=" * 60)
    print("最终结果")
    print("=" * 60)
    
    print("\n1. 卫星号（sv_num）:")
    print("-" * 40)
    
    print("GPS卫星:")
    for i, (sv_num, result) in enumerate(gps_sorted[:2]):
        print(f"  GPS卫星 {i+1}: sv_num = {sv_num}")
    
    print("BDS卫星:")
    for i, (sv_num, result) in enumerate(bds_sorted[:2]):
        print(f"  BDS卫星 {i+1}: sv_num = {sv_num}")
    
    print("\n2. 5位循环码:")
    print("-" * 40)
    
    print("GPS卫星:")
    for sv_num, cycle_code in gps_cycle_codes.items():
        print(f"  GPS SV {sv_num}: {''.join(map(str, cycle_code))}")
    
    print("BDS卫星:")
    for sv_num, cycle_code in bds_cycle_codes.items():
        print(f"  BDS SV {sv_num}: {''.join(map(str, cycle_code))}")
    
    # 保存结果到文件
    result_file = '/home/hp/cfy/ai_coding/BDS_GPS/reports/verification/results.txt'
    with open(result_file, 'w') as f:
        f.write("BDS/GPS C/A码捕获与跟踪结果\n")
        f.write("=" * 60 + "\n\n")
        
        f.write("1. 卫星号（sv_num）:\n")
        f.write("-" * 40 + "\n")
        
        f.write("GPS卫星:\n")
        for i, (sv_num, result) in enumerate(gps_sorted[:2]):
            f.write(f"  GPS卫星 {i+1}: sv_num = {sv_num}\n")
        
        f.write("BDS卫星:\n")
        for i, (sv_num, result) in enumerate(bds_sorted[:2]):
            f.write(f"  BDS卫星 {i+1}: sv_num = {sv_num}\n")
        
        f.write("\n2. 5位循环码:\n")
        f.write("-" * 40 + "\n")
        
        f.write("GPS卫星:\n")
        for sv_num, cycle_code in gps_cycle_codes.items():
            f.write(f"  GPS SV {sv_num}: {''.join(map(str, cycle_code))}\n")
        
        f.write("BDS卫星:\n")
        for sv_num, cycle_code in bds_cycle_codes.items():
            f.write(f"  BDS SV {sv_num}: {''.join(map(str, cycle_code))}\n")
    
    print(f"\n结果已保存到: {result_file}")
    
    return gps_results, bds_results, gps_cycle_codes, bds_cycle_codes


if __name__ == '__main__':
    main()