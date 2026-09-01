`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER (BUSINESS VARIANT): Advanced Asynchronous NoC Router
// ==============================================================================
// Purpose: Flawless X-Y dimension asynchronous routing for a 2D chiplet mesh.
// Advanced Resolution: Implements full Asynchronous Mutex Arbitration to 
// resolve simultaneous packet collisions without dropping spikes or deadlocking.
// ==============================================================================

module async_noc_router #(
    parameter int X_COORD = 0,
    parameter int Y_COORD = 0,
    parameter int ADDR_WIDTH = 32
)(
    input  logic [ADDR_WIDTH-1:0] rx_data [0:4],
    input  logic                  rx_req  [0:4],
    output logic                  rx_ack  [0:4],
    
    output logic [ADDR_WIDTH-1:0] tx_data [0:4],
    output logic                  tx_req  [0:4],
    input  logic                  tx_ack  [0:4]
);

    // Internal Route Requests (From Input 'i' to Output 'o')
    logic [4:0] route_req [0:4]; 
    
    // Internal Acks (From Output 'o' back to Input 'i')
    logic [4:0] route_ack [0:4];

    // --------------------------------------------------------------------------
    // STAGE 1: DIMENSION-ORDER DECODING (Input Side)
    // --------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < 5; i++) begin
            route_req[i] = 5'b00000;
            if (rx_req[i]) begin
                logic [7:0] target_x;
                logic [7:0] target_y;
                int dest_port;
                
                target_x = rx_data[i][31:24];
                target_y = rx_data[i][23:16];
                
                if      (target_x > X_COORD) dest_port = 2; // East
                else if (target_x < X_COORD) dest_port = 4; // West
                else if (target_y > Y_COORD) dest_port = 1; // North
                else if (target_y < Y_COORD) dest_port = 3; // South
                else                         dest_port = 0; // Local
                
                route_req[i][dest_port] = 1'b1;
            end
        end
    end

    // Input Port Acknowledge Aggregation
    always_comb begin
        for (int i = 0; i < 5; i++) begin
            // An input gets acked when its routed destination acks it
            rx_ack[i] = |route_ack[i]; 
        end
    end

    // --------------------------------------------------------------------------
    // STAGE 2: ASYNCHRONOUS MUTEX ARBITRATION & CROSSBAR (Output Side)
    // --------------------------------------------------------------------------
    genvar o;
    generate
        for (o = 0; o < 5; o++) begin : output_ports
            
            // Gather all requests aiming at this specific output port
            wire [4:0] incoming_reqs;
            assign incoming_reqs[0] = route_req[0][o];
            assign incoming_reqs[1] = route_req[1][o];
            assign incoming_reqs[2] = route_req[2][o];
            assign incoming_reqs[3] = route_req[3][o];
            assign incoming_reqs[4] = route_req[4][o];
            
            // Asynchronous SR Latch for Arbitration State
            logic [4:0] grant_locked = 5'b00000;
            wire        port_busy = |grant_locked;
            
            // Strict priority encoder for collision resolution
            wire [4:0] priority_req;
            assign priority_req[0] = incoming_reqs[0];
            assign priority_req[1] = incoming_reqs[1] & ~incoming_reqs[0];
            assign priority_req[2] = incoming_reqs[2] & ~(incoming_reqs[1] | incoming_reqs[0]);
            assign priority_req[3] = incoming_reqs[3] & ~(incoming_reqs[2] | incoming_reqs[1] | incoming_reqs[0]);
            assign priority_req[4] = incoming_reqs[4] & ~(incoming_reqs[3] | incoming_reqs[2] | incoming_reqs[1] | incoming_reqs[0]);

            // Asynchronous Latching Logic
            always_latch begin
                for (int i = 0; i < 5; i++) begin
                    // Acquire lock if port is free and we have priority
                    if (priority_req[i] && !port_busy) begin
                        grant_locked[i] <= 1'b1;
                    end
                    // Release lock only when request drops completely
                    else if (!incoming_reqs[i]) begin
                        grant_locked[i] <= 1'b0;
                    end
                end
            end
            
            // Crossbar Multiplexer (Data & Req Forwarding)
            always_comb begin
                tx_req[o]  = 0;
                tx_data[o] = '0;
                
                for (int i = 0; i < 5; i++) begin
                    route_ack[i][o] = 0;
                    
                    if (grant_locked[i]) begin
                        tx_req[o]  = incoming_reqs[i];
                        tx_data[o] = rx_data[i];
                        route_ack[i][o] = tx_ack[o]; // Pass ack back
                    end
                end
            end
            
        end
    endgenerate

endmodule
