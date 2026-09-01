`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Silicon Cochlea (With Noise Floor & Asymmetric OTA-C)
// ==============================================================================

module silicon_cochlea #(
    parameter int CHANNELS = 16 
)(
    input  real                  raw_audio_in, 
    output logic [CHANNELS-1:0]  aer_spike_out
);

    localparam real THRESHOLD = 0.5; 
    
    real bpf_voltage [0:CHANNELS-1];
    real center_freq [0:CHANNELS-1];
    
    initial begin
        for (int i = 0; i < CHANNELS; i++) begin
            bpf_voltage[i] = 0.0;
            center_freq[i] = 20.0 * (1.5 ** i); 
            aer_spike_out[i] = 0;
        end
    end

    real current_time, last_time, delta_t;
    initial last_time = 0;
    
    int seed;
    initial seed = $urandom();

    always #0.1 begin
        current_time = $realtime;
        delta_t = current_time - last_time;

        if (delta_t > 0) begin
            real noise_floor;
            // Inject continuous ~1mV Gaussian thermal noise floor
            noise_floor = ($dist_normal(seed, 0, 1) / 1000.0); 
            
            for (int i = 0; i < CHANNELS; i++) begin
                real damping;
                real dv;
                
                // Asymmetric Lyon Cochlear Damping
                // Fluids in the cochlea compress non-linearly.
                if (bpf_voltage[i] > 0) begin
                    damping = 0.2 * center_freq[i]; // High damping on attack
                end else begin
                    damping = 0.05 * center_freq[i]; // Low damping on release
                end
                
                dv = ((raw_audio_in + noise_floor) - (damping * bpf_voltage[i])) * delta_t * 1e-9;
                
                bpf_voltage[i] += dv;
                
                if (bpf_voltage[i] > THRESHOLD) begin
                    aer_spike_out[i] = 1;
                    bpf_voltage[i] = 0.0; 
                    #0.1 aer_spike_out[i] = 0; 
                end
            end
        end
        last_time = current_time;
    end

endmodule
