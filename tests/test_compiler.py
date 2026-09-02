import pytest
import numpy as np
import torch
from neuroforge.compiler import NeuroGraph, AnalogLinear
from neuroforge.nn import AnalogConv2d, AnalogSelfAttention
from neuroforge import LiquidSpikingActivation

def test_analog_linear_scaling():
    """Test if PyTorch weights are properly scaled to physical conductance boundaries."""
    layer = AnalogLinear(64, 128)
    weights = np.random.randn(128, 64)
    layer.load_pytorch_weights(weights)
    
    # Assert physical properties
    weights_np = np.array(layer.weights)
    assert weights_np.shape == (128, 64)
    assert np.min(weights_np) >= layer.g_min
    assert np.max(weights_np) <= layer.g_max

def test_analog_conv2d_im2col():
    """Test if Conv2d is successfully unrolled via Im2Col into a VMM Crossbar."""
    layer = AnalogConv2d(in_channels=3, out_channels=16, kernel_size=3)
    weights = np.random.randn(16, 3, 3, 3)
    layer.load_pytorch_weights(weights)
    
    # Assert spatial flattening
    assert layer.weights.shape == (16, 27) # 3 channels * 3x3 kernel
    
    # Assert mathematical forward pass (simulated)
    x = torch.randn(1, 3, 32, 32)
    out = layer(x)
    assert out.shape == (1, 16, 30, 30) # No padding, stride 1

def test_analog_self_attention_unpacking():
    """Test if the Transformer block correctly decomposes into 4 physical crossbars."""
    attn = AnalogSelfAttention(embed_dim=64, num_heads=4)
    w_q = np.random.randn(64, 64)
    w_k = np.random.randn(64, 64)
    w_v = np.random.randn(64, 64)
    w_o = np.random.randn(64, 64)
    attn.load_pytorch_weights(w_q, w_k, w_v, w_o)
    
    sub_layers = attn.get_physical_layers()
    assert len(sub_layers) == 4
    assert "Q_Proj" in sub_layers
    assert "Out_Proj" in sub_layers
    
    # Ensure they are AnalogLinear abstractions
    assert isinstance(sub_layers["Q_Proj"], AnalogLinear)

def test_liquid_spiking_activation_csr():
    """Test if LNN dynamically generates the correct hardware CSR boundaries."""
    lnn = LiquidSpikingActivation(num_neurons=128, init_v_thres=0.8, init_g_leak=1e-9)
    assert lnn.v_thres.shape == (128,)
    assert lnn.g_leak.shape == (128,)
    assert lnn.v_thres.mean().item() == pytest.approx(0.8, rel=1e-3)
