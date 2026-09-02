# The NeuroForge SDK Guide

NeuroForge is the bridge between Python-based AI research and asynchronous analog physics.

## 1. Core Abstractions
NeuroForge mirrors PyTorch's `nn.Module` philosophy but compiles down to physical `.mem` binaries.

### `AnalogLinear` & Matrix Shattering
Use `nf.compiler.AnalogLinear(in_features, out_features)` to define a standard fully-connected layer. 
**Under the Hood:** NeuroForge will automatically perform 8-bit Analog Quantization and apply Matrix Shattering if your dimensions exceed the $128 \times 128$ physical crossbar limits.

### `AnalogSelfAttention`
Maps Generative AI (LLMs/Transformers). NeuroForge natively splits this into four independent crossbar matrices: $Q$, $K$, $V$, and $Output\_Projection$.

### `LiquidSpikingActivation`
Maps continuous-time recurrent logic to the silicon using programmable Control and Status Registers (CSRs).

## 2. PPA Profiler
Run `neuroforge profile` to invoke the `NeuroForgeProfiler`.
It analyzes the output `noc_routing.json` to calculate exact microscopic dynamic energy (uJ) and static leakage based on active tiles, proving the superiority over Nvidia GPUs.

## 3. The Digital Twin Physics Engine
To simulate the hardware without actually fabbing the silicon, use `DigitalTwinSimulator`. 
This is not a mock function—it is an analytical physics engine. It calculates exact Parasitic RC Time Constants based on 22nm wire resistances and crossbar dimensions, yielding precise settling times (in picoseconds) for analog voltages.

## 4. Federated Swarm Protocol
Invoke `SwarmAgent` to interface with the SwarmHub. The SDK natively handles:
1. PUF signature extraction.
2. AES-256-GCM Payload Encryption (with Anti-Replay Nonces).
3. Secure HTTP POSTs to the distributed mesh.
4. Federated Averaging (FedAvg) to merge swarm weights back into the local hardware model.
