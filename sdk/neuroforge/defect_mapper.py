import numpy as np
import json
import os

class DefectMapper:
    """
    Cure 3: Manufacturing Yield Sector.
    Parses a physical silicon defect map and masks broken memristors 
    (Stuck-at-0 or Stuck-at-1) during the PyTorch-to-Silicon translation.
    """
    def __init__(self, defect_file="sdk/build/defect_map.json"):
        self.defects = {}
        if os.path.exists(defect_file):
            with open(defect_file, 'r') as f:
                self.defects = json.load(f)
            print(f"DefectMapper: Loaded physical silicon defect map for {len(self.defects)} tiles.")
        else:
            print("DefectMapper: No defect map found. Assuming 100% silicon yield.")

    def mask_tensor(self, tile_name, weights, g_min, g_max):
        """
        Applies physical defect constraints to the target weight matrix before it is compiled.
        """
        masked = np.copy(weights)
        if tile_name in self.defects:
            for defect in self.defects[tile_name]:
                row, col, stuck_type = defect["row"], defect["col"], defect["type"]
                if row < masked.shape[0] and col < masked.shape[1]:
                    if stuck_type == "SA0":
                        masked[row][col] = g_min
                    elif stuck_type == "SA1":
                        masked[row][col] = g_max
            print(f"DefectMapper: Masked {len(self.defects[tile_name])} broken memristors on {tile_name}.")
        return masked
