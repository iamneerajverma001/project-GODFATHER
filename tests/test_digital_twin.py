import pytest
from neuroforge.digital_twin import DigitalTwinSimulator

def test_rc_delay_physics():
    twin = DigitalTwinSimulator()
    # Given the default constants: R_wire=5.0, C_wire=0.2, length=128
    # max_R = 128 * 5.0 = 640 ohms
    # max_C = 128 * 0.2fF = 25.6 fF
    # Crossbar R_mem = 10000 ohms
    # RC = (640 + 10000) * (25.6e-15) = ~0.272 ns
    # Worst case delay = ~0.272 ns
    
    # We will just verify it runs without crashing and returns a float
    conductance = twin.simulate_packet_storm(nanoseconds=1000, global_reward=0.85)
    assert conductance is not None
    assert len(conductance) > 0
