`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER (BUSINESS VARIANT): Core Neuromorphic Tile
// ==============================================================================
// Purpose: A single 64-neuron cognitive block designed to be tile-instantiated 
// across a massive 2D NoC chiplet architecture.
// ==============================================================================

module godfather_core_tile #(
    parameter int TILE_X = 0,
    parameter int TILE_Y = 0,
    parameter int TILE_Z = 0,
    parameter int N_SENSORS = 64,
    parameter int N_NEURONS = 64
)(
    input  real sensor_voltages [0:N_SENSORS-1],
    input  real global_temp_celsius,
    
    // NoC Local Port Interface
    output logic [31:0] tx_aer_data,
    output logic        tx_aer_req,
    input  logic        tx_aer_ack,
    
    input  logic [31:0] rx_aer_data,
    input  logic        rx_aer_req,
    output logic        rx_aer_ack
);

    real crossbar_v_pre [0:N_SENSORS+16+N_NEURONS-1]; 
    real crossbar_v_post [0:N_NEURONS-1];
    real soma_currents [0:N_NEURONS-1];
    real soma_voltages [0:N_NEURONS-1];
    
    logic [N_NEURONS-1:0] neuron_spikes;
    logic [N_NEURONS-1:0] neuron_acks;
    logic [15:0]          local_aer_addr;

    // 1. Recurrent Analog Binding 
    always_comb begin
        for (int i = 0; i < N_SENSORS; i++) begin
            crossbar_v_pre[i] = sensor_voltages[i];
        end
        // Blanking auditory feedforward for Tile isolation in this iteration
        for (int i = 0; i < 16; i++) begin
            crossbar_v_pre[N_SENSORS + i] = 0.0;
        end
        for (int j = 0; j < N_NEURONS; j++) begin
            crossbar_v_pre[N_SENSORS + 16 + j] = neuron_spikes[j] ? 1.0 : 0.0;
            crossbar_v_post[j] = neuron_spikes[j] ? 1.0 : 0.0;
        end
    end

    // 2. Physics Layer
    real local_error_gradient;
    always_comb begin
        // The Holy Grail: Parsing Backward Error Gradients from the NoC AER Stream
        // If MSB [31] is 1, the packet is a supervised error gradient payload.
        if (rx_aer_req && rx_aer_data[31]) begin
            local_error_gradient = $signed(rx_aer_data[15:0]) / 1000.0; 
        end else begin
            local_error_gradient = 0.0;
        end
    end

    memristor_crossbar #(
        .N_PRE(N_SENSORS+16+N_NEURONS),
        .N_POST(N_NEURONS),
        .TILE_X(TILE_X),
        .TILE_Y(TILE_Y),
        .TILE_Z(TILE_Z)
    ) cognitive_matrix (
        .v_pre(crossbar_v_pre),
        .v_post(crossbar_v_post), 
        .error_gradient(local_error_gradient),
        .i_out(soma_currents)
    );

    genvar i;
    generate
        for (i = 0; i < N_NEURONS; i++) begin : neuron_array
            subthreshold_lif soma (
                .i_synaptic(soma_currents[i]),
                .temp_celsius(global_temp_celsius),
                .spike_out(neuron_spikes[i]),
                .spike_ack(neuron_acks[i]),
                .v_membrane(soma_voltages[i])
            );
        end
    endgenerate

    // 3. Local Asynchronous Mutex Routing (Spike -> AER Address)
    async_aer_router #(
        .ADDR_WIDTH(16),
        .NUM_INPUTS(N_NEURONS)
    ) local_router (
        .rx_reqs(neuron_spikes),
        .rx_acks(neuron_acks), 
        .tx_addr(local_aer_addr),
        .tx_req(tx_aer_req),
        .tx_ack(tx_aer_ack)
    );
    
    // Format the NoC 32-bit packet: [Y (8)] [X (8)] [Tile Local Addr (16)]
    assign tx_aer_data = {TILE_Y[7:0], TILE_X[7:0], local_aer_addr};
    
    // Acknowledge incoming NoC spikes instantly (sink for now)
    assign rx_aer_ack = rx_aer_req;

endmodule
