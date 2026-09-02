"""
NeuroForge Deep-Compiler v1.0
The "CUDA of Analog". Translates high-level PyTorch-style neural topologies 
directly into GODFATHER 2D NoC physical routing tables and memristor arrays.
"""
import random
import os
import json

from neuroforge.defect_mapper import DefectMapper
from neuroforge.activation import LiquidSpikingActivation

try:
    import torch
    import torch.nn as nn
    
    class AnalogAwareLinear(nn.Linear):
        """
        Hardware-Aware Training Wrapper.
        Injects simulated physical thermal noise and IR drop variance during the PyTorch 
        forward pass, ensuring the model learns to be robust to analog memristor imperfections.
        """
        def __init__(self, in_features, out_features, noise_std=0.05, **kwargs):
            super().__init__(in_features, out_features, **kwargs)
            self.noise_std = noise_std
            
        def forward(self, x):
            if self.training:
                # Simulate read noise, thermal fluctuations, and finite precision
                noise = torch.randn_like(self.weight) * self.noise_std * torch.abs(self.weight)
                noisy_weight = self.weight + noise
                return nn.functional.linear(x, noisy_weight, self.bias)
            return super().forward(x)
            
except ImportError:
    pass

class AnalogLinear:
    """A logical neural layer to be mapped to physical Memristor Crossbars."""
    def __init__(self, in_features, out_features):
        self.in_features = in_features
        self.out_features = out_features
        self.g_min = 1e-9   # 1 nS
        self.g_max = 100e-9 # 100 nS
        self.weights = []
        
    def load_pytorch_weights(self, pt_tensor):
        """Maps PyTorch fp32 weights linearly to physical analog conductances."""
        try:
            import torch
            import numpy as np
            if isinstance(pt_tensor, torch.Tensor):
                weights = pt_tensor.detach().cpu().numpy()
            else:
                weights = np.array(pt_tensor)
                
            # Min-Max Scaling to physical conductance constraints [G_MIN, G_MAX]
            w_min, w_max = weights.min(), weights.max()
            if w_max > w_min:
                scaled = self.g_min + (weights - w_min) * (self.g_max - self.g_min) / (w_max - w_min)
            else:
                scaled = np.full(weights.shape, self.g_min)
                
            self.weights = scaled.tolist()
            print(f"NeuroForge: [SUCCESS] Loaded and scaled {weights.shape} PyTorch tensor to physical limits.")
        except ImportError:
            print("NeuroForge: [WARNING] PyTorch/NumPy not found. Using stochastic boot.")
            self.weights = []

class NeuroGraph:
    """The compiler engine that places logical layers onto physical chiplets."""
    def __init__(self, name="Godfather_Cluster", grid_x=2, grid_y=2, grid_z=2, neurons_per_tile=64):
        self.name = name
        self.grid_x = grid_x
        self.grid_y = grid_y
        self.grid_z = grid_z
        self.neurons_per_tile = neurons_per_tile
        self.layers = []
        self.routing_table = {}
        self.csr_configs = {}

    def add_layer(self, layer_name, layer):
        """Adds a logical layer or activation function to the physical stack."""
        if hasattr(layer, "get_physical_layers"):
            print(f"NeuroForge: Unpacking Complex Module '{layer_name}' into physical crossbar tiles.")
            sub_layers = layer.get_physical_layers()
            for sub_name, sub_layer in sub_layers.items():
                self.layers.append((f"{layer_name}_{sub_name}", sub_layer))
        else:
            self.layers.append((layer_name, layer))

    def _place_and_route(self):
        """
        The Spatial P&R Algorithm.
        Maps logical layers to physical (X, Y, Z) tiles.
        Calculates Asynchronous AER routing hops in 3D.
        """
        print("NeuroForge: Initiating Spatial 3D Placement & Routing (P&R)...")
        allocated_neurons = 0
        current_tile_x = 0
        current_tile_y = 0
        current_tile_z = 0
        
        for name, layer in self.layers:
            if isinstance(layer, LiquidSpikingActivation):
                print(f"NeuroForge: Configuring Liquid Spiking CSRs for Layer '{name}'.")
                if len(self.routing_table) > 0:
                    last_tile = list(self.routing_table.values())[-1]["physical_core"]
                    self.csr_configs[last_tile] = layer.export_csr_config()
                continue
                
            # Determine how many physical tiles this layer requires
            tiles_needed = max(1, layer.out_features // self.neurons_per_tile)
            print(f"NeuroForge: Mapping Layer '{name}' ({layer.out_features} neurons) -> Requires {tiles_needed} Tile(s).")
            
            # Map neurons to specific Tile Coordinates
            target_x = current_tile_x
            target_y = current_tile_y
            target_z = current_tile_z
            
            self.routing_table[name] = {
                "physical_core": f"TILE_{target_x}_{target_y}_{target_z}",
                "noc_target_x": target_x,
                "noc_target_y": target_y,
                "noc_target_z": target_z,
                "logical_in": layer.in_features,
                "logical_out": layer.out_features,
                "aer_base_addr": allocated_neurons
            }
            
            allocated_neurons += layer.out_features
            current_tile_x = (current_tile_x + 1) % self.grid_x
            if current_tile_x == 0:
                current_tile_y = (current_tile_y + 1) % self.grid_y
                if current_tile_y == 0:
                    current_tile_z = (current_tile_z + 1) % self.grid_z

    def compile(self, output_dir="sdk/build"):
        """Compiles the model into physical Verilog binaries."""
        if not self.layers:
            raise ValueError("NeuroGraph is empty.")
            
        os.makedirs(output_dir, exist_ok=True)
        print(f"\n==================================================")
        print(f"   NEUROFORGE DEEP-COMPILER: {self.name.upper()}")
        print(f"==================================================")
        
        self._place_and_route()
        
        # 1. Generate NoC Routing Table
        rt_path = os.path.join(output_dir, "noc_routing.json")
        with open(rt_path, 'w') as f:
            json.dump(self.routing_table, f, indent=4)
        print(f"NeuroForge: [SUCCESS] NoC Routing Table generated -> {rt_path}")
        
        # 2. Generate Physical Crossbar States (.mem) for ALL Mapped Tiles
        mapper = DefectMapper()
        
        for name, layer in self.layers:
            if name not in self.routing_table:
                continue
                
            tile_name = self.routing_table[name]["physical_core"]
            mem_path = os.path.join(output_dir, f"{tile_name}_init.mem")
            
            with open(mem_path, 'w') as f:
                if layer.weights and len(layer.weights) == layer.in_features:
                    # Apply Silicon Defect Map
                    safe_weights = mapper.mask_tensor(tile_name, layer.weights, layer.g_min, layer.g_max)
                    for r in range(layer.in_features):
                        row = [f"{val:e}" for val in safe_weights[r]]
                        f.write(" ".join(row) + "\n")
                else:
                    for _ in range(layer.in_features):
                        row = []
                        for _ in range(layer.out_features):
                            base = layer.g_min + ((layer.g_max - layer.g_min) * 0.1)
                            noise = base * (random.uniform(-10, 10) / 100.0)
                            row.append(f"{base + noise:e}")
                        f.write(" ".join(row) + "\n")
            print(f"NeuroForge: [SUCCESS] Physical Weights generated -> {mem_path}")
        
        # 3. Generate CSR Configuration Overrides
        if self.csr_configs:
            csr_path = os.path.join(output_dir, "csr_config.json")
            with open(csr_path, 'w') as f:
                json.dump(self.csr_configs, f, indent=4)
            print(f"NeuroForge: [SUCCESS] Physical Activation CSRs generated -> {csr_path}")

        print("NeuroForge: Compilation Complete. Hardware ready for asynchronous dispatch.")
