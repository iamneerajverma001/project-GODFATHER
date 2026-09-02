`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER (ENTERPRISE 3D VARIANT): Asynchronous 3D TSV NoC Router
// ==============================================================================
// Purpose: Flawless X-Y-Z dimension asynchronous routing for a 3D chiplet stack.
// Advanced Resolution: Implements full 7-port Asynchronous Mutex Arbitration to 
// resolve simultaneous packet collisions in 3D space across Through-Silicon Vias.
// ==============================================================================

module async_noc_router #(
    parameter int X_COORD = 0,
    parameter int Y_COORD = 0,
    parameter int Z_COORD = 0,
    parameter int ADDR_WIDTH = 32
)(
    // Asynchronous Handshake Ports (Req/Ack/Data) for 7 directions
    // 0: Local, 1: North, 2: East, 3: South, 4: West, 5: Up (TSV), 6: Down (TSV)
    input  logic                  rst_n,   // Global asynchronous active-low reset
    input  logic                  thermal_throttle, // Cure 1: Dark Silicon Throttle
    input  logic [ADDR_WIDTH-1:0] rx_data [0:6],
    input  logic                  rx_req  [0:6],
    output logic                  rx_ack  [0:6],
    
    output logic [ADDR_WIDTH-1:0] tx_data [0:6],
    output logic                  tx_req  [0:6],
    input  logic                  tx_ack  [0:6]
);

    // Internal Route Requests (From Input 'i' to Output 'o')
    logic [6:0] route_req [0:6]; 
    
    // Internal Acks (From Output 'o' back to Input 'i')
    logic [6:0] route_ack [0:6];

    // --------------------------------------------------------------------------
    // STAGE 1: DIMENSION-ORDER DECODING (Input Side)
    // --------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < 7; i++) begin
            route_req[i] = 7'b0000000;
            if (rx_req[i]) begin
                logic [7:0] target_x;
                logic [7:0] target_y;
                logic [7:0] target_z;
                int dest_port;
                
                target_x = rx_data[i][31:24];
                target_y = rx_data[i][23:16];
                target_z = rx_data[i][15:8];
                
                // XYZ Dimension Routing Algorithm
                if      (target_x > X_COORD) dest_port = 2; // East
                else if (target_x < X_COORD) dest_port = 4; // West
                else if (target_y > Y_COORD) dest_port = 1; // North
                else if (target_y < Y_COORD) dest_port = 3; // South
                else if (target_z > Z_COORD) dest_port = 5; // Up (TSV)
                else if (target_z < Z_COORD) dest_port = 6; // Down (TSV)
                else                         dest_port = 0; // Local
                
                // Cure 1: Dark Silicon Thermal Throttling
                // Cure 5: Network Congestion Drop (Simulated via LFSR or simple drop logic)
                // If thermal throttling is active, drop 50% of spikes to prevent silicon melting.
                if (thermal_throttle && rx_data[i][0]) begin
                    // Drop packet (assert ack to sink it, but don't route it)
                    route_req[i] = 7'b0000000;
                end else begin
                    route_req[i][dest_port] = 1'b1;
                end
            end
        end
    end

    // Input Port Acknowledge Aggregation
    always_comb begin
        for (int i = 0; i < 7; i++) begin
            rx_ack[i] = (|route_ack[i]) || (rx_req[i] && thermal_throttle && rx_data[i][0]); 
        end
    end

    // --------------------------------------------------------------------------
    // STAGE 2: 7-WAY ASYNCHRONOUS MUTEX ARBITRATION (Output Side)
    // --------------------------------------------------------------------------
    genvar o;
    generate
        for (o = 0; o < 7; o++) begin : output_ports
            
            // Gather all requests aiming at this specific output port
            wire [6:0] incoming_reqs;
            assign incoming_reqs[0] = route_req[0][o];
            assign incoming_reqs[1] = route_req[1][o];
            assign incoming_reqs[2] = route_req[2][o];
            assign incoming_reqs[3] = route_req[3][o];
            assign incoming_reqs[4] = route_req[4][o];
            assign incoming_reqs[5] = route_req[5][o];
            assign incoming_reqs[6] = route_req[6][o];
            
            // Asynchronous SR Latch for Arbitration State
            logic [6:0] grant_locked = 7'b0000000;
            wire        port_busy = |grant_locked;
            
            // Strict priority encoder for collision resolution in 3D
            wire [6:0] p_req;
            assign p_req[0] = incoming_reqs[0];
            assign p_req[1] = incoming_reqs[1] & ~incoming_reqs[0];
            assign p_req[2] = incoming_reqs[2] & ~(|incoming_reqs[1:0]);
            assign p_req[3] = incoming_reqs[3] & ~(|incoming_reqs[2:0]);
            assign p_req[4] = incoming_reqs[4] & ~(|incoming_reqs[3:0]);
            assign p_req[5] = incoming_reqs[5] & ~(|incoming_reqs[4:0]);
            assign p_req[6] = incoming_reqs[6] & ~(|incoming_reqs[5:0]);

            // Asynchronous Latching Logic
            always_latch begin
                if (!rst_n) begin
                    for (int i = 0; i < 7; i++) grant_locked[i] <= 1'b0;
                end else begin
                    for (int i = 0; i < 7; i++) begin
                        if (p_req[i] && !port_busy) begin
                            grant_locked[i] <= 1'b1;
                        end
                        else if (!incoming_reqs[i]) begin
                            grant_locked[i] <= 1'b0;
                        end
                    end
                end
            end
            
            // Crossbar Multiplexer (Data & Req Forwarding)
            always_comb begin
                tx_req[o]  = 0;
                tx_data[o] = '0;
                
                for (int i = 0; i < 7; i++) begin
                    if (grant_locked[i]) begin
                        tx_req[o]  = incoming_reqs[i];
                        tx_data[o] = rx_data[i];
                    end
                end
            end
            
            // Route Acknowledge back to input port
            for (genvar i = 0; i < 7; i++) begin : ack_wiring
                assign route_ack[i][o] = grant_locked[i] ? tx_ack[o] : 1'b0;
            end
            
        end
    endgenerate

endmodule
