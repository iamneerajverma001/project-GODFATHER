`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: The Silicon Singularity - Top Level Matrix
// ==============================================================================
// Purpose: Binds the sub-threshold analog neurons, the memristor crossbars,
// and the asynchronous AER routing logic into a single mixed-signal domain.
// ==============================================================================

module godfather_top #(
    parameter int N_SENSORS = 64,
    parameter int N_NEURONS = 64
)(
    // Sensory input represented as continuous analog voltages
    input  real sensor_voltages [0:N_SENSORS-1],
    
    // Asynchronous Output Spikes (No Clock)
    output logic [15:0] out_aer_addr,
    output logic        out_aer_req,
    input  logic        out_aer_ack
);

    // -------------------------------------------------------------
    // 0. The Hardware Security Enclave (SRAM PUF)
    // -------------------------------------------------------------
    logic [255:0] creator_puf_key;
    logic         puf_ready;
    
    // In a real ASIC, power_on is the physical VCC rail.
    sram_puf #(.KEY_WIDTH(256)) hardware_root_of_trust (
        .power_on(1'b1), // Tied high for simulation
        .puf_key(creator_puf_key),
        .key_valid(puf_ready)
    );

    // -------------------------------------------------------------
    // 0.5 The Auditory Transducer (Silicon Cochlea)
    // -------------------------------------------------------------
    logic [15:0] auditory_spikes;
    
    silicon_cochlea #(.CHANNELS(16)) inner_ear (
        .raw_audio_in(0.0), // Tie to 0 for now; driven by testbench in full system
        .aer_spike_out(auditory_spikes)
    );

    // Total Crossbar Inputs = Sensors + Cochlea + Recurrent Feedback
    localparam int N_PRE = N_SENSORS + 16 + N_NEURONS;
    
    real crossbar_v_pre [0:N_PRE-1];
    real crossbar_v_post [0:N_NEURONS-1];
    
    // Internal Analog Nets
    real soma_currents [0:N_NEURONS-1];
    real soma_voltages [0:N_NEURONS-1];
    
    // Internal Digital Asynchronous Nets
    logic [N_NEURONS-1:0] neuron_spikes;
    logic [N_NEURONS-1:0] neuron_acks;

    // -------------------------------------------------------------
    // 1. Recurrent Analog Binding & Sensory Convergence
    // -------------------------------------------------------------
    always_comb begin
        // Feedforward Vision/Proprioception Array
        for (int i = 0; i < N_SENSORS; i++) begin
            crossbar_v_pre[i] = sensor_voltages[i];
        end
        
        // Feedforward Auditory Array (Convert digital spikes to analog 1.0V)
        for (int i = 0; i < 16; i++) begin
            crossbar_v_pre[N_SENSORS + i] = auditory_spikes[i] ? 1.0 : 0.0;
        end
        
        // Recurrent Cognitive Array
        // Because of the true Muller C-element handshake in the router, 
        // neuron_spikes[j] naturally stays high until acknowledged. 
        // This stretches the 1.0V pulse, providing a massive, biologically 
        // accurate time window for Hebbian STDP to thicken the memristor filament.
        for (int j = 0; j < N_NEURONS; j++) begin
            crossbar_v_pre[N_SENSORS + 16 + j] = neuron_spikes[j] ? 1.0 : 0.0;
            crossbar_v_post[j] = neuron_spikes[j] ? 1.0 : 0.0;
        end
    end

    // -------------------------------------------------------------
    // 2. The Physics Layer (Memristor Crossbar + Sub-threshold LIF)
    // -------------------------------------------------------------
    memristor_crossbar #(
        .N_PRE(N_PRE),
        .N_POST(N_NEURONS)
    ) cognitive_matrix (
        .v_pre(crossbar_v_pre),
        .v_post(crossbar_v_post), 
        .i_out(soma_currents)
    );

    genvar i;
    generate
        for (i = 0; i < N_NEURONS; i++) begin : neuron_array
            subthreshold_lif soma (
                .i_synaptic(soma_currents[i]),
                .temp_celsius(25.0), // Default room temperature
                .spike_out(neuron_spikes[i]),
                .spike_ack(neuron_acks[i]), // Closed-loop Muller C-element handshake
                .v_membrane(soma_voltages[i])
            );
        end
    endgenerate

    // -------------------------------------------------------------
    // 3. The Clockless Digital Layer (Async Routing Mutex Tree)
    // -------------------------------------------------------------
    // The neurons output independent asynchronous spikes. 
    // The Mutex Tree Arbiter resolves simultaneous physical collisions safely.

    async_aer_router #(
        .ADDR_WIDTH(16),
        .NUM_INPUTS(N_NEURONS)
    ) router (
        .rx_reqs(neuron_spikes),
        .rx_acks(neuron_acks), // Wire the feedback acks to clear the neurons
        .tx_addr(out_aer_addr),
        .tx_req(out_aer_req),
        .tx_ack(out_aer_ack)
    );

endmodule
