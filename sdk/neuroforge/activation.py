import torch
import torch.nn as nn

class LiquidSpikingActivation(nn.Module):
    """
    NeuroForge: Liquid Neural Network (LNN) Activation Layer.
    
    This PyTorch module simulates the sub-threshold Leaky Integrate-and-Fire (LIF)
    physics of the GODFATHER chip. Crucially, it exposes the time-constant (leakage)
    and threshold as learnable PyTorch parameters.
    
    When compiled via NeuroForge, these parameters are extracted and flashed 
    directly into the hardware CSRs (csr_v_thres, csr_g_leak) of the NoC tiles,
    allowing the silicon to physically reshape its temporal dynamics on the fly.
    """
    def __init__(self, num_neurons, init_v_thres=0.8, init_g_leak=10.0e-9):
        super().__init__()
        self.num_neurons = num_neurons
        
        # Learnable Physical Constraints (Mapped to Hardware CSRs)
        self.v_thres = nn.Parameter(torch.full((num_neurons,), init_v_thres))
        self.g_leak = nn.Parameter(torch.full((num_neurons,), init_g_leak))
        
        # Internal state for forward pass simulation
        self.v_mem = None

    def reset_state(self, batch_size):
        """Resets the membrane potentials for a new temporal sequence."""
        self.v_mem = torch.zeros(batch_size, self.num_neurons, device=self.v_thres.device)

    def forward(self, x, dt=1.0):
        """
        Simulates the analog integration and spiking.
        x: Input synaptic current
        dt: Time delta
        """
        if self.v_mem is None or self.v_mem.shape[0] != x.shape[0]:
            self.reset_state(x.shape[0])
            
        # Membrane physics simulation: dV/dt = I - G_leak * V
        leakage = self.g_leak * self.v_mem
        dv = (x - leakage) * dt
        self.v_mem = self.v_mem + dv
        
        # Spiking logic (Differentiable surrogate gradient would go here for BPTT)
        spikes = (self.v_mem >= self.v_thres).float()
        
        # Reset membrane potential after spike
        self.v_mem = self.v_mem * (1.0 - spikes)
        
        return spikes

    def export_csr_config(self):
        """
        Extracts the learned physical parameters into a JSON-serializable dictionary
        for the Deep Compiler to inject into the physical silicon CSRs.
        """
        return {
            "csr_v_thres": self.v_thres.detach().cpu().numpy().tolist(),
            "csr_g_leak": self.g_leak.detach().cpu().numpy().tolist()
        }
