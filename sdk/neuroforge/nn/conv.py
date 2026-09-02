import torch
import torch.nn as nn
import numpy as np

class AnalogConv2d(nn.Module):
    """
    NeuroForge: Analog 2D Convolution Layer (cuDNN Equivalent)
    
    This abstracts PyTorch's Conv2d into a format physically computable by 
    memristor crossbars. Because crossbars perform VMM (Vector-Matrix Multiplication),
    convolutions must be mathematically unrolled using the Im2Col (Image-to-Column) 
    transformation before compilation.
    """
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0, g_min=1e-6, g_max=100e-6):
        super().__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride
        self.padding = padding
        
        # Physical device constraints
        self.g_min = g_min
        self.g_max = g_max
        
        # The unrolled kernel footprint
        self.unrolled_in_features = in_channels * self.kernel_size[0] * self.kernel_size[1]
        self.out_features = out_channels # Maps to distinct output neurons (filters)
        self.in_features = self.unrolled_in_features
        
        # Simulated PyTorch weights (for algorithmic training)
        self.weight = nn.Parameter(torch.Tensor(out_channels, self.unrolled_in_features))
        nn.init.kaiming_uniform_(self.weight, a=np.sqrt(5))
        
        # The physical weights (scaled to conductance)
        self.physical_weights = None
        
    def load_pytorch_weights(self, weights: np.ndarray):
        """
        Loads standard Conv2d weights and physically scales them to conductance (Siemens).
        weights shape: (out_channels, in_channels, kernel_h, kernel_w)
        """
        assert weights.shape == (self.out_channels, self.in_channels, self.kernel_size[0], self.kernel_size[1])
        # Flatten the spatial dimensions to map to crossbar rows
        unrolled = weights.reshape(self.out_channels, -1)
        
        # Min-Max Scaling to physical conductance range
        w_min, w_max = unrolled.min(), unrolled.max()
        if w_max == w_min:
            scaled = np.full_like(unrolled, self.g_min)
        else:
            scaled = self.g_min + ((unrolled - w_min) / (w_max - w_min)) * (self.g_max - self.g_min)
            
        self.physical_weights = scaled
        print(f"AnalogConv2d: Im2Col Unrolled Weights -> shape {self.physical_weights.shape}")
        
    def forward(self, x):
        """
        Algorithmic forward pass using PyTorch's native unfold (Im2Col).
        This perfectly simulates the spatial unrolling done by the hardware AER router.
        """
        # x shape: (Batch, Channels, H, W)
        batch_size = x.shape[0]
        
        # Hardware mathematically unrolls the input volume into temporal spikes
        unfolded = torch.nn.functional.unfold(x, kernel_size=self.kernel_size, padding=self.padding, stride=self.stride)
        # unfolded shape: (Batch, in_channels*k*k, L) where L is number of patches
        
        # Perform Vector-Matrix Multiplication (simulating the Crossbar)
        # weight shape: (out_channels, in_channels*k*k)
        out = self.weight @ unfolded
        # out shape: (Batch, out_channels, L)
        
        # Fold back into spatial dimensions (Requires output H/W calculation)
        h_out = (x.shape[2] + 2 * self.padding - self.kernel_size[0]) // self.stride + 1
        w_out = (x.shape[3] + 2 * self.padding - self.kernel_size[1]) // self.stride + 1
        
        out = out.view(batch_size, self.out_channels, h_out, w_out)
        return out

    @property
    def weights(self):
        """Property accessed by the NeuroForge Compiler to generate .mem files."""
        return self.physical_weights
