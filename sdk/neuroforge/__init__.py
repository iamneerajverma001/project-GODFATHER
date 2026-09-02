# ==============================================================================
# NeuroForge SDK v1.0
# The Official Software Ecosystem for Project GODFATHER.
# 
# A PyTorch-compatible deep-compiler that seamlessly shatters, quantizes, 
# and routes standard Neural Networks into asynchronous analog Silicon.
# ==============================================================================


from .compiler import NeuroGraph, AnalogLinear, AnalogAwareLinear
from .digital_twin import DigitalTwinSimulator
from .optimizer import NeuroForgeOptimizer
from .swarm_protocol import SwarmAgent, SwarmOrchestrator
from .defect_mapper import DefectMapper
from .activation import LiquidSpikingActivation
from .profiler import NeuroForgeProfiler
from . import nn

__all__ = [
    "NeuroGraph",
    "AnalogLinear",
    "AnalogAwareLinear",
    "DigitalTwinSimulator",
    "NeuroForgeOptimizer",
    "SwarmAgent",
    "SwarmOrchestrator",
    "DefectMapper",
    "LiquidSpikingActivation",
    "NeuroForgeProfiler",
    "nn"
]

def render_brain_telemetry(csv_path, output_dir):
    # Dummy import handler for backward compatibility with scripts
    pass
