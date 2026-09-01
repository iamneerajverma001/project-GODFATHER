`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Silicon Retina (Dynamic Vision Sensor - DVS)
// ==============================================================================
// Purpose: Event-based vision sensor modeled after the human retina.
// Mechanics: Detects logarithmic changes in pixel illumination. Emits completely 
//            asynchronous Address-Events (AER) ONLY when pixels change state, 
//            bypassing frame-rates and eliminating temporal redundancy.
// ==============================================================================

module silicon_retina #(
    parameter int RES_X = 16,
    parameter int RES_Y = 16,
    parameter real THRESHOLD_ON = 0.2,  // Log intensity change to fire ON spike
    parameter real THRESHOLD_OFF = -0.2 // Log intensity change to fire OFF spike
)(
    // Physical Environment Inputs (Analog Illumination)
    input  real pixel_illumination [0:RES_X-1][0:RES_Y-1],
    
    // Asynchronous AER Output Interface
    output logic [31:0] out_aer_data,
    output logic        out_aer_req,
    input  logic        out_aer_ack
);

    // Internal analog state for logarithmic photoreceptors
    real prev_log_illumination [0:RES_X-1][0:RES_Y-1];
    
    // Spike queuing (since multiple pixels can fire simultaneously in simulation)
    // We use a simple structural queue to serialize concurrent physical events into AER
    
    typedef struct {
        logic [7:0] x;
        logic [7:0] y;
        logic polarity; // 1 = ON, 0 = OFF
    } spike_t;
    
    spike_t spike_queue [$:1023]; // SystemVerilog Queue
    
    // Initialization
    initial begin
        out_aer_req = 0;
        out_aer_data = '0;
        for (int x = 0; x < RES_X; x++) begin
            for (int y = 0; y < RES_Y; y++) begin
                prev_log_illumination[x][y] = $ln(0.001); // Baseline
            end
        end
    end
    
    // Continuous sampling of the analog environment (in reality, continuous time analog diff-amp)
    // Here we sample every 1ns to model the ultra-fast analog response
    always begin
        #1.0; 
        for (int x = 0; x < RES_X; x++) begin
            for (int y = 0; y < RES_Y; y++) begin
                automatic real current_ill = pixel_illumination[x][y];
                automatic real current_log = 0.0;
                automatic real diff = 0.0;
                
                // Prevent log(0)
                if (current_ill > 0.001) current_log = $ln(current_ill);
                else current_log = $ln(0.001);
                
                diff = current_log - prev_log_illumination[x][y];
                
                if (diff >= THRESHOLD_ON) begin
                    automatic spike_t s; 
                    s.x = x; s.y = y; s.polarity = 1;
                    spike_queue.push_back(s);
                    prev_log_illumination[x][y] = current_log;
                end
                else if (diff <= THRESHOLD_OFF) begin
                    automatic spike_t s; 
                    s.x = x; s.y = y; s.polarity = 0;
                    spike_queue.push_back(s);
                    prev_log_illumination[x][y] = current_log;
                end
            end
        end
    end
    
    // Asynchronous AER Dispatcher
    always begin
        if (spike_queue.size() > 0 && !out_aer_req) begin
            automatic spike_t s = spike_queue.pop_front();
            // Data format: [31:24]=X, [23:16]=Y, [0]=Polarity
            out_aer_data = {s.x, s.y, 15'b0, s.polarity};
            out_aer_req = 1;
            
            // Wait for handshake
            wait(out_aer_ack == 1);
            out_aer_req = 0;
            wait(out_aer_ack == 0);
        end
        else begin
            #0.1; // Poll queue
        end
    end

endmodule
