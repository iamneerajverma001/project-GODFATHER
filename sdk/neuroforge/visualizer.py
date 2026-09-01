"""
NeuroForge Visualizer
Renders the raw hardware telemetry into visual learning heatmaps.
"""
import os
import numpy as np
try:
    import matplotlib.pyplot as plt
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False

def render_brain_telemetry(filename="brain_telemetry.csv", output_dir="renders"):
    if not os.path.exists(filename):
        print(f"NeuroForge Error: {filename} not found.")
        return

    print(f"NeuroForge: Processing {filename}...")
    
    matrices = []
    current_matrix = []
    
    with open(filename, 'r') as f:
        for line in f:
            if line.strip() == "===":
                if current_matrix:
                    matrices.append(np.array(current_matrix))
                    current_matrix = []
            else:
                # Remove trailing comma and parse
                clean_line = line.strip().rstrip(',')
                if clean_line:
                    row = [float(x) for x in clean_line.split(',')]
                    current_matrix.append(row)
                    
    print(f"NeuroForge: Successfully extracted {len(matrices)} temporal states.")
    
    if not MATPLOTLIB_AVAILABLE:
        print("NeuroForge: 'matplotlib' is not installed. Skipping graphical rendering.")
        print("Run 'pip install matplotlib numpy' to enable 2D/3D heatmaps.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print("NeuroForge: Rendering physical STDP heatmaps...")
    
    # Render the Initial State
    plt.figure(figsize=(8, 6))
    plt.imshow(matrices[0], cmap='inferno', aspect='auto')
    plt.colorbar(label='Conductance (Siemens)')
    plt.title('Memristor Crossbar: Initial State (t=0)')
    plt.savefig(os.path.join(output_dir, 'state_initial.png'))
    plt.close()

    # Render the Final State
    plt.figure(figsize=(8, 6))
    plt.imshow(matrices[-1], cmap='inferno', aspect='auto')
    plt.colorbar(label='Conductance (Siemens)')
    plt.title(f'Memristor Crossbar: Final State (t={len(matrices)}) - Post-STDP')
    plt.savefig(os.path.join(output_dir, 'state_final.png'))
    plt.close()
    
    # Calculate the Delta (What the chip actually learned)
    delta_matrix = matrices[-1] - matrices[0]
    
    # Calculate symmetric bounds for the bwr colormap to ensure zero is white
    max_abs_delta = np.max(np.abs(delta_matrix))
    
    plt.figure(figsize=(8, 6))
    # Add vmin/vmax to ensure the diverging colormap centers on 0 and actually scales to the data, 
    # instead of auto-scaling to an unnoticeable near-zero noise floor or washing out.
    plt.imshow(delta_matrix, cmap='bwr', aspect='auto', vmin=-max_abs_delta, vmax=max_abs_delta) 
    plt.colorbar(label='Delta Conductance')
    plt.title('Neuroplasticity Map (What the chip learned)')
    plt.savefig(os.path.join(output_dir, 'state_delta_learning.png'))
    plt.close()

    print(f"NeuroForge: Rendering complete. Heatmaps saved to '{output_dir}/'.")
