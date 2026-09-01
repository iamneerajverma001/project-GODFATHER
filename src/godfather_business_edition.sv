`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER (BUSINESS VARIANT): Trillion-Dollar Enterprise Chiplet
// ==============================================================================
// Purpose: A massive 2D Hierarchical Asynchronous Mesh NoC.
// Instantiates a grid of GodFather Tiles communicating purely via asynchronous 
// physical AER spikes. Designed for 3D packaging and UCIe scaling.
// ==============================================================================

module godfather_business_edition #(
    parameter int MESH_X = 2,
    parameter int MESH_Y = 2
)(
    input logic power_on,
    input real  global_sensor_voltages [0:MESH_X-1][0:MESH_Y-1][0:63],
    input real  global_temp_celsius,
    
    // Enterprise PUF Identity
    output logic [255:0] chiplet_identity,
    output logic         identity_valid
);

    // Hardware Root of Trust
    sram_puf #(
        .KEY_WIDTH(256),
        .THERMAL_NOISE_PERCENT(10)
    ) secure_enclave (
        .power_on(power_on),
        .puf_key(chiplet_identity),
        .key_valid(identity_valid)
    );

    // Massive Mesh Interconnect (Arrays of handshakes)
    // 0: Local, 1: North, 2: East, 3: South, 4: West, 5: Up, 6: Down
    logic [31:0] link_data [0:MESH_X-1][0:MESH_Y-1][0:6];
    logic        link_req  [0:MESH_X-1][0:MESH_Y-1][0:6];
    logic        link_ack  [0:MESH_X-1][0:MESH_Y-1][0:6];

    logic [31:0] router_tx_data [0:MESH_X-1][0:MESH_Y-1][0:6];
    logic        router_tx_req  [0:MESH_X-1][0:MESH_Y-1][0:6];
    logic        router_tx_ack  [0:MESH_X-1][0:MESH_Y-1][0:6];

    genvar x, y;
    generate
        for (x = 0; x < MESH_X; x++) begin : mesh_col
            for (y = 0; y < MESH_Y; y++) begin : mesh_row
            
                // 1. The Physics Cognitive Tile
                godfather_core_tile #(
                    .TILE_X(x),
                    .TILE_Y(y)
                ) tile (
                    .sensor_voltages(global_sensor_voltages[x][y]),
                    .global_temp_celsius(global_temp_celsius),
                    .tx_aer_data(link_data[x][y][0]),
                    .tx_aer_req(link_req[x][y][0]),
                    .tx_aer_ack(link_ack[x][y][0]),
                    
                    .rx_aer_data(router_tx_data[x][y][0]),
                    .rx_aer_req(router_tx_req[x][y][0]),
                    .rx_aer_ack(router_tx_ack[x][y][0])
                );

                // 2. The 7-Port Asynchronous 3D TSV NoC Router
                async_noc_router #(
                    .X_COORD(x),
                    .Y_COORD(y),
                    .Z_COORD(0), // Layer 0 for 2D base chiplet
                    .ADDR_WIDTH(32)
                ) router (
                    .rx_data(link_data[x][y]),
                    .rx_req(link_req[x][y]),
                    .rx_ack(link_ack[x][y]),
                    
                    .tx_data(router_tx_data[x][y]),
                    .tx_req(router_tx_req[x][y]),
                    .tx_ack(router_tx_ack[x][y])
                );
                
                // (Omitted: Explicit X-Y-Z neighbor wiring for brevity)
                // For massive stress testing, we auto-acknowledge all router outputs
                // to simulate an infinitely fast receiving mesh and prevent deadlocks
                // from unconnected ports (except Local Port 0, which is wired).
                for (genvar p = 1; p < 7; p++) begin
                    assign router_tx_ack[x][y][p] = router_tx_req[x][y][p];
                end
                
            end
        end
    endgenerate

endmodule
