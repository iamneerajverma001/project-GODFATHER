`timescale 1ns/1ps

module spi_bootloader #(
    parameter PACKET_WIDTH = 64
)(
    input  logic sys_clk,
    input  logic rst_n,
    
    // External SPI Interface (From Host PC / Microcontroller)
    input  logic spi_sclk,
    input  logic spi_cs_n,
    input  logic spi_mosi,
    output logic spi_miso,
    
    // Asynchronous NoC Injection Interface (Flashing the 3D Grid)
    output logic [PACKET_WIDTH-1:0] noc_boot_data,
    output logic noc_boot_req,
    input  logic noc_boot_ack
);

    // SPI Shift Register state
    logic [PACKET_WIDTH-1:0] shift_reg;
    logic [6:0] bit_counter;
    logic packet_ready;
    
    // CDC Synchronizers for SPI Clock to System Clock
    logic sclk_sync1, sclk_sync2, sclk_sync3;
    logic cs_n_sync1, cs_n_sync2;
    
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync1 <= 1'b0; sclk_sync2 <= 1'b0; sclk_sync3 <= 1'b0;
            cs_n_sync1 <= 1'b1; cs_n_sync2 <= 1'b1;
        end else begin
            sclk_sync1 <= spi_sclk; sclk_sync2 <= sclk_sync1; sclk_sync3 <= sclk_sync2;
            cs_n_sync1 <= spi_cs_n; cs_n_sync2 <= cs_n_sync1;
        end
    end
    
    // Detect SPI Clock Edges
    wire sclk_rising  = (sclk_sync2 && !sclk_sync3);
    wire sclk_falling = (!sclk_sync2 && sclk_sync3);
    
    // Bootloader FSM
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_counter <= '0;
            packet_ready <= 1'b0;
            noc_boot_req <= 1'b0;
            noc_boot_data <= '0;
        end else begin
            if (cs_n_sync2) begin
                // Chip Select is HIGH (Inactive)
                bit_counter <= '0;
                packet_ready <= 1'b0;
            end else if (sclk_rising) begin
                // Shift in MOSI data
                shift_reg <= {shift_reg[PACKET_WIDTH-2:0], spi_mosi};
                bit_counter <= bit_counter + 1;
                
                if (bit_counter == PACKET_WIDTH - 1) begin
                    packet_ready <= 1'b1;
                end
            end
            
            // Asynchronous Handshake to NoC Router
            if (packet_ready && !noc_boot_req && !noc_boot_ack) begin
                noc_boot_data <= shift_reg;
                noc_boot_req  <= 1'b1;
                packet_ready  <= 1'b0;
                bit_counter   <= '0; // Reset for next packet
            end else if (noc_boot_req && noc_boot_ack) begin
                noc_boot_req  <= 1'b0; // Clear request once injected
            end
        end
    end

    // MISO Output (For Host verification/readback)
    assign spi_miso = shift_reg[PACKET_WIDTH-1];

endmodule
