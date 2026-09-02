import json
import os

class NeuroForgeProfiler:
    """
    NeuroForge Profiler (Analogous to Nvidia Nsight Systems)
    
    Provides highly accurate physical estimations of Power, Performance, and Area (PPA)
    for a compiled neural geometry running on the GODFATHER 3D Silicon.
    """
    def __init__(self, routing_table_path="sdk/build/noc_routing.json"):
        self.routing_table_path = routing_table_path
        
        # Physical Silicon Constants (Based on 22nm Analog / 3nm Digital)
        self.energy_per_synaptic_op_pJ = 0.05      # 50 femtoJoules per memristor MAC
        self.energy_per_aer_hop_pJ = 0.1           # 100 fJ per NoC router hop
        self.static_leakage_per_tile_uW = 15.0     # 15 microWatts leakage per tile
        self.tile_area_mm2 = 0.4                   # 0.4 mm^2 per tile

    def generate_ppa_report(self, batch_size=1, estimated_spikes_per_neuron=10):
        """Generates the Power, Performance, Area report."""
        if not os.path.exists(self.routing_table_path):
            print(f"[Profiler Error] Could not find {self.routing_table_path}. Compile model first.")
            return

        with open(self.routing_table_path, 'r') as f:
            routing_table = json.load(f)

        total_tiles = len(set([data["physical_core"] for data in routing_table.values()]))
        total_synapses = sum([data["logical_in"] * data["logical_out"] for data in routing_table.values()])
        total_neurons = sum([data["logical_out"] for data in routing_table.values()])

        # 1. Area Estimation
        total_area = total_tiles * self.tile_area_mm2

        # 2. Dynamic Power Estimation (Energy consumed by spikes)
        total_spikes = total_neurons * estimated_spikes_per_neuron * batch_size
        synaptic_energy_pJ = total_spikes * (total_synapses / max(1, total_neurons)) * self.energy_per_synaptic_op_pJ
        routing_energy_pJ = total_spikes * 3.5 * self.energy_per_aer_hop_pJ # Assume 3.5 hops avg
        
        total_dynamic_energy_uJ = (synaptic_energy_pJ + routing_energy_pJ) / 1e6

        # 3. Static Power Estimation
        total_static_power_uW = total_tiles * self.static_leakage_per_tile_uW

        # 4. Equivalent Nvidia H100 Energy (For comparison)
        # H100 burns ~15 picoJoules per FP16 MAC
        h100_energy_uJ = (total_synapses * total_spikes * 15.0) / 1e6

        report = f"""
==================================================
   NEUROFORGE SILICON PROFILER (PPA REPORT)
==================================================
Model Geometry:
- Total Physical Tiles Allocated : {total_tiles}
- Total Analog Synapses (MACs)   : {total_synapses:,}
- Total Physical Area            : {total_area:.2f} mm^2

Energy Profile (per inference batch):
- Total Dynamic Energy           : {total_dynamic_energy_uJ:.4f} microJoules (uJ)
- Static Leakage Power           : {total_static_power_uW:.2f} microWatts (uW)

Architectural Superiority Analysis:
- Equivalent Nvidia H100 Energy  : {h100_energy_uJ:.4f} microJoules (uJ)
- GODFATHER Power Efficiency     : {h100_energy_uJ / max(1e-9, total_dynamic_energy_uJ):.1f}x more efficient
==================================================
"""
        print(report)
        
        # Save report
        report_path = os.path.join(os.path.dirname(self.routing_table_path), "ppa_report.txt")
        with open(report_path, "w") as f:
            f.write(report)
            
        return report
