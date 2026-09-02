`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Asynchronous Mutex Tree Arbiter (UPGRADED)
// ==============================================================================
// Purpose: Replaced the naive Priority Encoder with a robust binary MUTEX TREE.
// Resolves metastability when simultaneous analog spikes fire, guaranteeing 
// zero deadlocks and perfectly isolated Address Event Representation (AER).
// ==============================================================================

module async_aer_router #(
    parameter int ADDR_WIDTH = 16,
    parameter int NUM_INPUTS = 64
)(
    input  logic [NUM_INPUTS-1:0] rx_reqs,
    output logic [NUM_INPUTS-1:0] rx_acks,
    
    output logic [ADDR_WIDTH-1:0] tx_addr,
    output logic                  tx_req,
    input  logic                  tx_ack
);

    // Hardcoded for NUM_INPUTS = 64 (A 6-level binary tree of Mutex elements)
    // Level 0: 64 inputs -> 32 nodes
    // Level 1: 32 inputs -> 16 nodes
    // Level 2: 16 inputs -> 8 nodes
    // Level 3: 8 inputs  -> 4 nodes
    // Level 4: 4 inputs  -> 2 nodes
    // Level 5: 2 inputs  -> 1 node (Root)

    logic [63:0] L0_req, L0_ack;
    logic [ADDR_WIDTH-1:0] L0_addr [0:63];

    // Initialize Base Layer addresses
    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : init_layer
            assign L0_req[i] = rx_reqs[i];
            assign rx_acks[i] = L0_ack[i];
            assign L0_addr[i] = i; // Address is just the index
        end
    endgenerate

    // ========================================================
    // Recursive Mutex Tree Instantiation
    // ========================================================
    
    // Level 1
    logic [31:0] L1_req, L1_ack;
    logic [ADDR_WIDTH-1:0] L1_addr [0:31];
    generate for (i=0; i<32; i++) begin : mut_l1
        mutex_node node (.req_0(L0_req[2*i]), .req_1(L0_req[2*i+1]), .gnt_0(L0_ack[2*i]), .gnt_1(L0_ack[2*i+1]),
                         .req_out(L1_req[i]), .ack_in(L1_ack[i]), .addr_0(L0_addr[2*i]), .addr_1(L0_addr[2*i+1]), .addr_out(L1_addr[i]));
    end endgenerate

    // Level 2
    logic [15:0] L2_req, L2_ack;
    logic [ADDR_WIDTH-1:0] L2_addr [0:15];
    generate for (i=0; i<16; i++) begin : mut_l2
        mutex_node node (.req_0(L1_req[2*i]), .req_1(L1_req[2*i+1]), .gnt_0(L1_ack[2*i]), .gnt_1(L1_ack[2*i+1]),
                         .req_out(L2_req[i]), .ack_in(L2_ack[i]), .addr_0(L1_addr[2*i]), .addr_1(L1_addr[2*i+1]), .addr_out(L2_addr[i]));
    end endgenerate

    // Level 3
    logic [7:0] L3_req, L3_ack;
    logic [ADDR_WIDTH-1:0] L3_addr [0:7];
    generate for (i=0; i<8; i++) begin : mut_l3
        mutex_node node (.req_0(L2_req[2*i]), .req_1(L2_req[2*i+1]), .gnt_0(L2_ack[2*i]), .gnt_1(L2_ack[2*i+1]),
                         .req_out(L3_req[i]), .ack_in(L3_ack[i]), .addr_0(L2_addr[2*i]), .addr_1(L2_addr[2*i+1]), .addr_out(L3_addr[i]));
    end endgenerate

    // Level 4
    logic [3:0] L4_req, L4_ack;
    logic [ADDR_WIDTH-1:0] L4_addr [0:3];
    generate for (i=0; i<4; i++) begin : mut_l4
        mutex_node node (.req_0(L3_req[2*i]), .req_1(L3_req[2*i+1]), .gnt_0(L3_ack[2*i]), .gnt_1(L3_ack[2*i+1]),
                         .req_out(L4_req[i]), .ack_in(L4_ack[i]), .addr_0(L3_addr[2*i]), .addr_1(L3_addr[2*i+1]), .addr_out(L4_addr[i]));
    end endgenerate

    // Level 5
    logic [1:0] L5_req, L5_ack;
    logic [ADDR_WIDTH-1:0] L5_addr [0:1];
    generate for (i=0; i<2; i++) begin : mut_l5
        mutex_node node (.req_0(L4_req[2*i]), .req_1(L4_req[2*i+1]), .gnt_0(L4_ack[2*i]), .gnt_1(L4_ack[2*i+1]),
                         .req_out(L5_req[i]), .ack_in(L5_ack[i]), .addr_0(L4_addr[2*i]), .addr_1(L4_addr[2*i+1]), .addr_out(L5_addr[i]));
    end endgenerate

    // Root Level (Level 6)
    mutex_node root_node (
        .req_0(L5_req[0]), .req_1(L5_req[1]), 
        .gnt_0(L5_ack[0]), .gnt_1(L5_ack[1]),
        .req_out(tx_req), .ack_in(tx_ack), 
        .addr_0(L5_addr[0]), .addr_1(L5_addr[1]), 
        .addr_out(tx_addr)
    );

endmodule
