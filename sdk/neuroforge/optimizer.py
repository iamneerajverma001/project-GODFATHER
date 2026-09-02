import numpy as np

try:
    import torch
    import torch.nn as nn
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False

class NeuroForgeOptimizer:
    """
    Cure 2: The SDK Optimizer Sector (The Holy Grail Controller)
    This bridges PyTorch loss functions (e.g. CrossEntropy) directly to the 
    physical silicon 3-Factor R-STDP physics engine via AER Error Gradients.
    """
    def __init__(self, digital_twin, learning_rate=0.01):
        self.digital_twin = digital_twin
        self.learning_rate = learning_rate
        if not TORCH_AVAILABLE:
            print("NeuroForgeOptimizer: [WARNING] PyTorch not found. Falling back to Numpy.")

    def step(self, predictions, targets, loss_fn=None):
        """
        Calculates the physical error gradient from PyTorch tensors,
        and broadcasts it into the asynchronous 3D NoC as an MSB=1 Error Spike.
        """
        print(f"\n[NeuroForgeOptimizer] Initiating 3-Factor Error Injection...")
        
        if TORCH_AVAILABLE and isinstance(predictions, torch.Tensor):
            if loss_fn is None:
                loss_fn = nn.MSELoss()
            loss = loss_fn(predictions, targets)
            loss.backward()
            
            # Extract scalar global reward/error gradient for the physics engine
            global_error = -float(loss.item()) * self.learning_rate
            
            print(f"NeuroForgeOptimizer: Computed PyTorch Loss = {loss.item():.4f}")
            print(f"NeuroForgeOptimizer: Injecting scaled physical gradient = {global_error:.4f} into 3D NoC.")
            
            # Inject via Digital Twin (mimicking Wafer-Scale Edge Transceivers)
            self.digital_twin.simulate_packet_storm(nanoseconds=1000, global_reward=global_error)
            
            return loss.item()
        else:
            # Numpy Fallback
            error = np.mean((predictions - targets) ** 2)
            global_error = -float(error) * self.learning_rate
            
            print(f"NeuroForgeOptimizer: Computed Numpy Error = {error:.4f}")
            print(f"NeuroForgeOptimizer: Injecting scaled physical gradient = {global_error:.4f} into 3D NoC.")
            
            self.digital_twin.simulate_packet_storm(nanoseconds=1000, global_reward=global_error)
            
            return error
