import pytest
import os
import numpy as np
from neuroforge.compiler import NeuroGraph, AnalogLinear
from neuroforge.profiler import NeuroForgeProfiler
from neuroforge.nn import AnalogSelfAttention

def test_full_compilation_pipeline(tmp_path):
    """End-to-end integration test of compiling a Transformer into physical binaries."""
    model = NeuroGraph(name="Test_Cluster", grid_x=2, grid_y=2, grid_z=2)
    
    # 1. Add layers
    layer1 = AnalogLinear(32, 64)
    layer1.load_pytorch_weights(np.random.randn(64, 32))
    model.add_layer("Layer1", layer1)
    
    from neuroforge import LiquidSpikingActivation
    model.add_layer("LNN1", LiquidSpikingActivation(64))
    
    attn = AnalogSelfAttention(embed_dim=64, num_heads=2)
    attn.load_pytorch_weights(np.random.randn(64,64), np.random.randn(64,64), np.random.randn(64,64), np.random.randn(64,64))
    model.add_layer("Attention", attn)
    
    # 2. Compile to a temporary build directory
    build_dir = tmp_path / "build"
    build_dir.mkdir()
    model.compile(output_dir=str(build_dir))
    
    # 3. Assert Outputs
    assert os.path.exists(os.path.join(build_dir, "noc_routing.json"))
    assert os.path.exists(os.path.join(build_dir, "csr_config.json"))
    
    # Assert physical .mem files were generated for the tiles
    assert os.path.exists(os.path.join(build_dir, "TILE_0_0_0_init.mem"))
    
    # 4. Assert PPA Profiler works
    profiler = NeuroForgeProfiler(routing_table_path=os.path.join(build_dir, "noc_routing.json"))
    report = profiler.generate_ppa_report()
    
    assert "NEUROFORGE SILICON PROFILER" in report
    assert "GODFATHER Power Efficiency" in report
    assert os.path.exists(os.path.join(build_dir, "ppa_report.txt"))
