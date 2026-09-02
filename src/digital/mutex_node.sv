`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Asynchronous Tree Arbiter Node (2-Input Mutex)
// ==============================================================================

module mutex_node (
    input  logic req_0,
    input  logic req_1,
    output logic gnt_0,
    output logic gnt_1,
    
    output logic req_out,
    input  logic ack_in,
    
    input  logic [15:0] addr_0,
    input  logic [15:0] addr_1,
    output logic [15:0] addr_out
);

    // Mutual Exclusion (Cross-coupled NANDs modeled in behavioral RTL)
    logic int_gnt_0, int_gnt_1;
    
    always_comb begin
        if (req_0 && !int_gnt_1) begin
            int_gnt_0 = 1'b1;
            int_gnt_1 = 1'b0;
        end else if (req_1 && !int_gnt_0) begin
            int_gnt_0 = 1'b0;
            int_gnt_1 = 1'b1;
        end else begin
            int_gnt_0 = 1'b0;
            int_gnt_1 = 1'b0;
        end
    end
    
    assign req_out = int_gnt_0 | int_gnt_1;
    assign gnt_0   = int_gnt_0 & ack_in;
    assign gnt_1   = int_gnt_1 & ack_in;
    
    // Muxing the address up the tree
    assign addr_out = int_gnt_0 ? addr_0 : (int_gnt_1 ? addr_1 : 16'h0000);

endmodule
