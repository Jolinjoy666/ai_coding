#!/usr/bin/env python3
"""
AttentionCore-SOC Golden Model Generator
Generates reference outputs for verification using PyTorch.
"""

import torch
import torch.nn as nn
import numpy as np
import os

# Configuration (matching SOC parameters)
D_MODEL = 16
N_HEAD = 2
HEAD_DIM = D_MODEL // N_HEAD
NUM_LAYERS = 2
SEQ_LEN = 8
D_FF = 64

class AttentionCoreGoldenModel(nn.Module):
    """PyTorch reference model for AttentionCore-SOC."""

    def __init__(self, d_model=D_MODEL, nhead=N_HEAD, num_layers=NUM_LAYERS, d_ff=D_FF):
        super().__init__()
        self.encoder = nn.TransformerEncoder(
            nn.TransformerEncoderLayer(
                d_model=d_model,
                nhead=nhead,
                dim_feedforward=d_ff,
                batch_first=True,
                dtype=torch.float16
            ),
            num_layers=num_layers
        )

    def forward(self, x):
        return self.encoder(x)

def generate_test_vectors(num_tests=10):
    """Generate random test vectors."""
    test_vectors = []

    for i in range(num_tests):
        # Random input in FP16 range
        x = torch.randn(1, SEQ_LEN, D_MODEL, dtype=torch.float16)

        # Random weights (would be fixed in real verification)
        test_vectors.append({
            'input': x,
            'seed': i
        })

    return test_vectors

def generate_golden_outputs(test_vectors):
    """Generate golden outputs for test vectors."""
    model = AttentionCoreGoldenModel()
    model.eval()

    golden_outputs = []

    with torch.no_grad():
        for tv in test_vectors:
            output = model(tv['input'])
            golden_outputs.append({
                'input': tv['input'].numpy(),
                'output': output.numpy(),
                'seed': tv['seed']
            })

    return golden_outputs

def save_golden_data(golden_outputs, output_dir='golden'):
    """Save golden data to files for RTL verification."""
    os.makedirs(output_dir, exist_ok=True)

    for i, go in enumerate(golden_outputs):
        # Save input
        input_file = os.path.join(output_dir, f'input_{i:04d}.bin')
        go['input'].tofile(input_file)

        # Save output
        output_file = os.path.join(output_dir, f'output_{i:04d}.bin')
        go['output'].tofile(output_file)

    # Save configuration
    config_file = os.path.join(output_dir, 'config.txt')
    with open(config_file, 'w') as f:
        f.write(f'D_MODEL={D_MODEL}\n')
        f.write(f'N_HEAD={N_HEAD}\n')
        f.write(f'HEAD_DIM={HEAD_DIM}\n')
        f.write(f'NUM_LAYERS={NUM_LAYERS}\n')
        f.write(f'SEQ_LEN={SEQ_LEN}\n')
        f.write(f'D_FF={D_FF}\n')
        f.write(f'NUM_TESTS={len(golden_outputs)}\n')

    print(f"Generated {len(golden_outputs)} golden test cases in {output_dir}/")

def generate_fp16_test_data():
    """Generate specific FP16 test data for unit tests."""
    test_data = {
        'fp16_values': [
            0x3C00,  # 1.0
            0x4000,  # 2.0
            0x4200,  # 3.0
            0x4400,  # 4.0
            0x3800,  # 0.5
            0x3400,  # 0.25
            0xBC00,  # -1.0
            0xC000,  # -2.0
            0x0000,  # 0.0
            0x7C00,  # +inf
            0xFC00,  # -inf
            0x7E00,  # NaN
        ],
        'fp16_multiply_pairs': [
            (0x3C00, 0x3C00, 0x3C00),  # 1.0 * 1.0 = 1.0
            (0x4000, 0x4200, 0x4600),  # 2.0 * 3.0 = 6.0
            (0x3800, 0x4000, 0x3C00),  # 0.5 * 2.0 = 1.0
            (0xBC00, 0x3C00, 0xBC00),  # -1.0 * 1.0 = -1.0
        ]
    }

    return test_data

def main():
    print("Generating AttentionCore-SOC Golden Model Data...")

    # Generate test vectors
    test_vectors = generate_test_vectors(num_tests=100)

    # Generate golden outputs
    golden_outputs = generate_golden_outputs(test_vectors)

    # Save golden data
    save_golden_data(golden_outputs, 'golden')

    # Generate FP16 test data
    fp16_data = generate_fp16_test_data()

    # Save FP16 test data
    import json
    with open('golden/fp16_tests.json', 'w') as f:
        json.dump(fp16_data, f, indent=2)

    print("Golden model generation complete!")

if __name__ == '__main__':
    main()
