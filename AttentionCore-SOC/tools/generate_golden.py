#!/usr/bin/env python3
"""
AttentionCore-SOC Golden Model Generator
Generates reference outputs for verification using PyTorch.
"""

import torch
import torch.nn as nn
import numpy as np
import os
import math

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


def generate_attention_golden(output_dir='golden'):
    """Generate Q, K, V and expected output for scaled dot-product attention.

    Memory layout (FP16, row-major):
      Feature SRAM[0..63]   = Q (SEQ_LEN x D_MODEL = 8x16 = 128 bytes = 64 FP16 words)
      KV-Cache SRAM[0..63]  = K (SEQ_LEN x D_MODEL = 64 FP16 words)
      KV-Cache SRAM[64..127]= V (SEQ_LEN x D_MODEL = 64 FP16 words)
      Feature SRAM[128..191]= O (output, 64 FP16 words)

    For multi-head (N_HEAD=2, HEAD_DIM=8):
      Q[head h] = Q[h*8 .. h*8+7] per row
    """
    torch.manual_seed(42)

    SEQ_LEN = 8
    D_MODEL = 16
    N_HEAD = 2
    HEAD_DIM = D_MODEL // N_HEAD  # 8

    # Generate Q, K, V: [SEQ_LEN, D_MODEL] in FP16
    Q = torch.randn(SEQ_LEN, D_MODEL, dtype=torch.float32)
    K = torch.randn(SEQ_LEN, D_MODEL, dtype=torch.float32)
    V = torch.randn(SEQ_LEN, D_MODEL, dtype=torch.float32)

    # Clip to avoid overflow in FP16
    Q = torch.clamp(Q, -4.0, 4.0)
    K = torch.clamp(K, -4.0, 4.0)
    V = torch.clamp(V, -4.0, 4.0)

    Q_fp16 = Q.half()
    K_fp16 = K.half()
    V_fp16 = V.half()

    # Compute attention per head
    scale = 1.0 / math.sqrt(HEAD_DIM)
    O_heads = []

    for h in range(N_HEAD):
        # Extract head: [SEQ_LEN, HEAD_DIM]
        q_h = Q_fp16[:, h*HEAD_DIM:(h+1)*HEAD_DIM]
        k_h = K_fp16[:, h*HEAD_DIM:(h+1)*HEAD_DIM]
        v_h = V_fp16[:, h*HEAD_DIM:(h+1)*HEAD_DIM]

        # S = Q * K^T * scale  [SEQ_LEN, SEQ_LEN]
        S = torch.matmul(q_h.float(), k_h.float().T) * scale
        S_fp16 = S.half()

        # P = softmax(S) - compute in FP32 for accuracy
        P = torch.softmax(S.float(), dim=-1).half()

        # O = P * V  [SEQ_LEN, HEAD_DIM]
        O_h = torch.matmul(P.float(), v_h.float()).half()
        O_heads.append(O_h)

    # Concatenate heads: [SEQ_LEN, D_MODEL]
    O = torch.cat(O_heads, dim=-1)

    # Save as FP16 binary files
    os.makedirs(output_dir, exist_ok=True)

    # Flatten to 1D FP16 array (row-major)
    Q_flat = Q_fp16.numpy().flatten()
    K_flat = K_fp16.numpy().flatten()
    V_flat = V_fp16.numpy().flatten()
    O_flat = O.numpy().flatten()

    # Convert to FP16 binary (2 bytes per value)
    Q_flat.astype(np.float16).tofile(os.path.join(output_dir, 'q_input.bin'))
    K_flat.astype(np.float16).tofile(os.path.join(output_dir, 'k_input.bin'))
    V_flat.astype(np.float16).tofile(os.path.join(output_dir, 'v_input.bin'))
    O_flat.astype(np.float16).tofile(os.path.join(output_dir, 'attention_output.bin'))

    # Save as hex text for UVM test
    with open(os.path.join(output_dir, 'q_input.hex'), 'w') as f:
        for val in Q_flat:
            fp16_val = np.float16(val)
            raw = int(fp16_val.view(np.uint16))
            f.write(f'{raw:04X}\n')

    with open(os.path.join(output_dir, 'k_input.hex'), 'w') as f:
        for val in K_flat:
            fp16_val = np.float16(val)
            raw = int(fp16_val.view(np.uint16))
            f.write(f'{raw:04X}\n')

    with open(os.path.join(output_dir, 'v_input.hex'), 'w') as f:
        for val in V_flat:
            fp16_val = np.float16(val)
            raw = int(fp16_val.view(np.uint16))
            f.write(f'{raw:04X}\n')

    with open(os.path.join(output_dir, 'attention_output.hex'), 'w') as f:
        for val in O_flat:
            fp16_val = np.float16(val)
            raw = int(fp16_val.view(np.uint16))
            f.write(f'{raw:04X}\n')

    print(f"Generated attention golden data in {output_dir}/")
    print(f"  Q: {Q_flat.shape} values, range [{Q_flat.min():.4f}, {Q_flat.max():.4f}]")
    print(f"  K: {K_flat.shape} values, range [{K_flat.min():.4f}, {K_flat.max():.4f}]")
    print(f"  V: {V_flat.shape} values, range [{V_flat.min():.4f}, {V_flat.max():.4f}]")
    print(f"  O: {O_flat.shape} values, range [{O_flat.min():.4f}, {O_flat.max():.4f}]")

    return Q_fp16, K_fp16, V_fp16, O

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

    # Generate attention golden data for e2e test
    generate_attention_golden('golden')

    print("Golden model generation complete!")

if __name__ == '__main__':
    main()
