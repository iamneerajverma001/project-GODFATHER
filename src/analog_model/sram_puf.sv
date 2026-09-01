`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: The Creator's Interlock (SRAM PUF with Thermal Noise & ECC)
// ==============================================================================

module sram_puf #(
    parameter int KEY_WIDTH = 256,
    parameter int THERMAL_NOISE_PERCENT = 10 // 10% chance of a bit flipping on boot
)(
    input  logic                 power_on, 
    output logic [KEY_WIDTH-1:0] puf_key,
    output logic                 key_valid
);

    logic [KEY_WIDTH-1:0] physical_mismatch_mask;
    
    initial begin
        $srandom(32'h1337BEEF); 
        for (int i = 0; i < KEY_WIDTH/32; i++) begin
            physical_mismatch_mask[i*32 +: 32] = $urandom();
        end
        puf_key = '0;
        key_valid = 0;
    end

    logic [KEY_WIDTH-1:0] raw_noisy_puf_read;
    logic [KEY_WIDTH-1:0] ecc_corrected_key;

    // Power-on Race Condition with Thermal Noise
    always @(posedge power_on) begin
        #5.2; 
        
        // Inject physical thermal noise (Bit-flips)
        for (int i = 0; i < KEY_WIDTH; i++) begin
            if (($urandom_range(0, 100)) < THERMAL_NOISE_PERCENT) begin
                raw_noisy_puf_read[i] = ~physical_mismatch_mask[i]; // Flipped by thermal noise
            end else begin
                raw_noisy_puf_read[i] = physical_mismatch_mask[i];  // Stable
            end
        end
        
        // In a physical chip, we would use Helper Data and BCH/Hamming codes.
        // Here, we simulate a perfect Fuzzy Extractor by running an abstract ECC algorithm
        // that corrects up to 15% BER (Bit Error Rate) instantly to guarantee stability.
        ecc_corrected_key = physical_mismatch_mask; // The mathematical ideal after ECC extraction
        
        puf_key = ecc_corrected_key;
        key_valid = 1;
    end
    
    always @(negedge power_on) begin
        puf_key = '0;
        key_valid = 0;
    end

endmodule
