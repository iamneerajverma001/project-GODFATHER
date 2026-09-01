`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER (BUSINESS VARIANT): 5-Port Asynchronous NoC Router
// ==============================================================================
// Purpose: X-Y dimension asynchronous routing for a 2D mesh of GodFather Tiles.
// Ports: North, South, East, West, Local (Tile).
// ==============================================================================

module async_noc_router #(
    parameter int X_COORD = 0,
    parameter int Y_COORD = 0,
    parameter int ADDR_WIDTH = 32 // Upper 16 = Tile ID, Lower 16 = Neuron ID
)(
    // Asynchronous Handshake Ports (Req/Ack/Data) for 5 directions
    // 0: Local, 1: North, 2: East, 3: South, 4: West
    input  logic [ADDR_WIDTH-1:0] rx_data [0:4],
    input  logic                  rx_req  [0:4],
    output logic                  rx_ack  [0:4],
    
    output logic [ADDR_WIDTH-1:0] tx_data [0:4],
    output logic                  tx_req  [0:4],
    input  logic                  tx_ack  [0:4]
);

    // Simplified X-Y Routing Logic (Dimension-Order Routing)
    // In true silicon, each port has a Mutex arbiter to handle simultaneous arrivals.
    always_comb begin
        // Default assignments
        for (int i = 0; i < 5; i++) begin
            tx_req[i] = 0;
            tx_data[i] = '0;
            rx_ack[i] = 0;
        end

        // Process incoming requests
        for (int i = 0; i < 5; i++) begin
            if (rx_req[i]) begin
                logic [7:0] target_x;
                logic [7:0] target_y;
                int route_port;
                
                target_x = rx_data[i][31:24];
                target_y = rx_data[i][23:16];
                
                // X-Y Dimension Routing Algorithm
                if (target_x > X_COORD)      route_port = 2; // East
                else if (target_x < X_COORD) route_port = 4; // West
                else if (target_y > Y_COORD) route_port = 1; // North
                else if (target_y < Y_COORD) route_port = 3; // South
                else                         route_port = 0; // Local Tile
                
                // Forward the asynchronous handshake
                tx_data[route_port] = rx_data[i];
                tx_req[route_port]  = rx_req[i];
                rx_ack[i]           = tx_ack[route_port];
            end
        end
    end

endmodule
