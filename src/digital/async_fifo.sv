`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Dual-Clock Asynchronous FIFO (CDC Synchronizer)
// ==============================================================================
// Purpose: Cures the Phase 5 Metastability Flaw. 
// Safely bridges the purely asynchronous NoC brain to the synchronous 
// AES-256 Crypto Engine and Swarm Telemetry interfaces using Gray-code pointers.
// ==============================================================================

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 4 // Depth = 16
)(
    // Asynchronous Write Domain (Driven by NoC Routers)
    input  logic                  async_req,
    output logic                  async_ack,
    input  logic [DATA_WIDTH-1:0] async_data,
    
    // Synchronous Read Domain (Driven by Crypto Engine)
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  read_en,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic                  empty
);

    localparam int DEPTH = 1 << ADDR_WIDTH;
    
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    logic [ADDR_WIDTH:0] wptr_bin = 0, wptr_gray = 0;
    logic [ADDR_WIDTH:0] rptr_bin = 0, rptr_gray = 0;
    
    logic [ADDR_WIDTH:0] rptr_gray_sync1, rptr_gray_sync2;
    logic [ADDR_WIDTH:0] wptr_gray_sync1, wptr_gray_sync2;
    
    logic full;
    
    // --------------------------------------------------------------------------
    // ASYNCHRONOUS WRITE DOMAIN (Emulating a Req/Ack handshake)
    // --------------------------------------------------------------------------
    // In a true async design, req acts as a clock or trigger for the write.
    // For Verilog modeling, we latch on posedge of async_req.
    always @(posedge async_req or negedge rst_n) begin
        if (!rst_n) begin
            wptr_bin <= 0;
            wptr_gray <= 0;
            async_ack <= 0;
        end else begin
            if (!full) begin
                mem[wptr_bin[ADDR_WIDTH-1:0]] <= async_data;
                wptr_bin <= wptr_bin + 1;
                wptr_gray <= (wptr_bin + 1) ^ ((wptr_bin + 1) >> 1);
            end
            async_ack <= 1; // Acknowledge the request
        end
    end
    
    // Clear ack when req goes low
    always @(negedge async_req) begin
        async_ack <= 0;
    end
    
    // --------------------------------------------------------------------------
    // SYNCHRONOUS READ DOMAIN
    // --------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rptr_bin <= 0;
            rptr_gray <= 0;
        end else begin
            if (read_en && !empty) begin
                rptr_bin <= rptr_bin + 1;
                rptr_gray <= (rptr_bin + 1) ^ ((rptr_bin + 1) >> 1);
            end
        end
    end
    
    assign read_data = mem[rptr_bin[ADDR_WIDTH-1:0]];
    
    // --------------------------------------------------------------------------
    // DUAL-CLOCK SYNCHRONIZERS
    // --------------------------------------------------------------------------
    // Sync read pointer into write domain
    always @(posedge async_req or negedge rst_n) begin
        if (!rst_n) begin
            rptr_gray_sync1 <= 0;
            rptr_gray_sync2 <= 0;
        end else begin
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end
    end
    
    // Sync write pointer into read domain
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr_gray_sync1 <= 0;
            wptr_gray_sync2 <= 0;
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end
    
    // --------------------------------------------------------------------------
    // FULL / EMPTY LOGIC
    // --------------------------------------------------------------------------
    assign empty = (rptr_gray == wptr_gray_sync2);
    
    assign full = (wptr_gray == {~rptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                  rptr_gray_sync2[ADDR_WIDTH-2:0]});

endmodule
