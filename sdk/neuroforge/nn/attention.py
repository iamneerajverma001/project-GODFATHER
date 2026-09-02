import torch
import torch.nn as nn
import numpy as np
from neuroforge.compiler import AnalogLinear

class AnalogSelfAttention(nn.Module):
    """
    NeuroForge: Analog Self-Attention Block (For LLMs / Transformers)
    
    This is the Holy Grail of modern AI hardware: Mapping the Transformer Attention
    mechanism ($Softmax(QK^T)V$) onto physical Memristor Crossbars.
    
    Physical Mapping Strategy:
    1. The W_q, W_k, and W_v projection matrices are static and perfectly mapped
       to 3 distinct Analog Crossbar Tiles.
    2. The dynamic Q*K^T multiplication (Activation x Activation) is handled
       by the digital peripheral ALUs inside the NoC routers (since memristors
       can only do Activation x Static_Weight).
    """
    def __init__(self, embed_dim, num_heads, g_min=1e-6, g_max=100e-6):
        super().__init__()
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.head_dim = embed_dim // num_heads
        assert self.head_dim * num_heads == self.embed_dim, "embed_dim must be divisible by num_heads"
        
        # 3 Physical Analog Crossbars for the Projections
        self.q_proj = AnalogLinear(embed_dim, embed_dim)
        self.k_proj = AnalogLinear(embed_dim, embed_dim)
        self.v_proj = AnalogLinear(embed_dim, embed_dim)
        
        # Output projection crossbar
        self.out_proj = AnalogLinear(embed_dim, embed_dim)

    def load_pytorch_weights(self, w_q: np.ndarray, w_k: np.ndarray, w_v: np.ndarray, w_out: np.ndarray):
        """Loads and scales standard PyTorch Attention weights into physical conductance."""
        self.q_proj.load_pytorch_weights(w_q)
        self.k_proj.load_pytorch_weights(w_k)
        self.v_proj.load_pytorch_weights(w_v)
        self.out_proj.load_pytorch_weights(w_out)
        print(f"AnalogSelfAttention: [SUCCESS] Q, K, V, Out matrices scaled to physical conductance.")

    def forward(self, x):
        """
        Algorithmic forward pass simulating the hybrid Analog-Digital attention execution.
        x shape: (Batch, Seq_Len, Embed_Dim)
        """
        batch_size, seq_len, embed_dim = x.shape
        
        # 1. Analog Vector-Matrix Multiplications (Physically executed on Crossbars)
        # We reshape x to (Batch * Seq_Len, Embed_Dim) to push through the Linear abstractions
        x_flat = x.view(-1, embed_dim)
        
        q = self.q_proj(x_flat).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(x_flat).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(x_flat).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)
        
        # 2. Digital Peripheral Processing (Physically executed in NoC router ALUs)
        # Q * K^T
        scores = torch.matmul(q, k.transpose(-2, -1)) / np.sqrt(self.head_dim)
        attn_weights = torch.nn.functional.softmax(scores, dim=-1)
        
        # Attention * V
        context = torch.matmul(attn_weights, v)
        context = context.transpose(1, 2).contiguous().view(batch_size * seq_len, embed_dim)
        
        # 3. Final Analog Output Projection
        out = self.out_proj(context).view(batch_size, seq_len, embed_dim)
        return out

    def get_physical_layers(self):
        """Returns the internal AnalogLinear layers so the Deep Compiler can route them."""
        return {
            "Q_Proj": self.q_proj,
            "K_Proj": self.k_proj,
            "V_Proj": self.v_proj,
            "Out_Proj": self.out_proj
        }
