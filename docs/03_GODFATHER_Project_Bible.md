# Project GODFATHER: The Technical Bible

This document serves as the absolute source of truth for the architectural, mathematical, and cryptographic implementations of the GODFATHER System-on-Chip (SoC).

## 1. The Hardware Architecture (Wafer-Scale Neuromorphic)

### 1.1 The Asynchronous NoC (Network-on-Chip)
Unlike standard GPUs which rely on a massive global clock (causing enormous power draw), GODFATHER operates asynchronously. We utilize **AER (Address Event Representation)**. Data is transmitted purely as voltage spikes across the 3D grid. The NoC routers (`src/digital/async_noc_router.sv`) sleep at 0 Watts until a voltage spike arrives, triggering a request/acknowledge handshake.

### 1.2 The Memristor Crossbar
The computational core of the chip is the 1S1R (1-Selector 1-Resistor) Memristor Crossbar.
Vector-Matrix Multiplications (VMM) are executed physically in $O(1)$ time using:
* **Ohm's Law ($I = V \times G$):** Input voltage vectors multiply against the memristance state (Conductance $G$).
* **Kirchhoff's Current Law ($\sum I = I_{out}$):** The currents naturally sum down the bitlines.

### 1.3 The SPI Host Bootloader (CURE 2)
To load initial PyTorch parameters into the silicon, the `spi_bootloader.sv` acts as a physical bridge. It syncs the Host PC clock to the internal asynchronous clock using CDC (Clock Domain Crossing) synchronizers, catching 64-bit packets via the MOSI pin and dispatching them into the NoC to flash the crossbars.

## 2. The Software SDK (NeuroForge)

### 2.1 Deep-Compiler Matrix Shattering (CURE 1)
Modern AI models (like LLMs) have matrices far exceeding physical silicon constraints. A standard memristor crossbar maxes out at $128 \times 128$.
NeuroForge intercepts standard PyTorch layers and executes **Spatial Partitioning (Shattering)**. A $512 \times 256$ matrix is shattered into exactly eight $128 \times 128$ physical tile chunks, routed perfectly over the NoC.

### 2.2 8-Bit Analog Quantization (CURE 1)
Floating-point PyTorch weights are intercepted and quantized. The compiler calculates $2^8 = 256$ discrete physical conductance levels between $G_{min}$ (1 nS) and $G_{max}$ (100 nS), snapping the PyTorch weights to physically achievable resistance states.

### 2.3 The Digital Twin Physics Engine (CURE 3)
The SDK avoids slow EDA SPICE solvers by implementing a mathematical RC delay engine. 
Based on a 22nm node (Wire Resistance $R_{wire} = 5.0 \Omega/\mu m$ and Capacitance $C_{wire} = 0.2$ fF/$\mu m$), the engine dynamically calculates the absolute worst-case settling time for the analog signals, allowing exact cycle-accurate simulations.

## 3. The Swarm Intelligence Network

### 3.1 3-Factor R-STDP (On-Chip Learning)
GODFATHER chips do not need backpropagation in the cloud. They learn dynamically at the edge using **Reward-Modulated Spike-Timing-Dependent Plasticity**. An eligibility trace is left in the memristor when a spike passes; if a global reward (dopamine) is injected within a few milliseconds, the conductance physically updates.

### 3.2 Cryptographic Root of Trust
Each chip has a physical SRAM PUF (Physically Unclonable Function). This generates a unique 256-bit signature derived from manufacturing impurities. This signature generates an AES-256-GCM key inside the `swarm_protocol.py`.

### 3.3 Zero-Trust Federated Averaging (CURE 4)
When edge devices share their STDP learnings with the SwarmHub:
1. **Replay Attack Protection:** Encrypted payloads include a UUIDv4 Nonce and physical timestamp. Duplicate nonces are instantly rejected by the Hub.
2. **FedAvg Math:** Agents pull the global encrypted ledger, decrypt it, and use NumPy to calculate the statistical mean of the swarm. They then apply an Exponential Moving Average ($W_{new} = \alpha W_{local} + (1-\alpha) W_{swarm\_mean}$) to physically merge the collective intelligence into their own silicon brain.
