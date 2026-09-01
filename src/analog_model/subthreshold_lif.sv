`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: Sub-threshold Analog LIF Neuron Model (With Thermal/Mismatch)
// ==============================================================================

module subthreshold_lif #(
    parameter real C_MEMBRANE = 1.0e-12, 
    parameter real G_LEAK_TYP = 10.0e-9, 
    parameter real V_REST = 0.0,         
    parameter real V_THRES_TYP = 0.8,    
    parameter real V_RESET = -0.2,       
    parameter real REFRACTORY_TIME = 2.0 
)(
    input  real  i_synaptic,        
    input  real  temp_celsius,      
    output logic spike_out,         
    input  logic spike_ack,         // True Asynchronous Handshake
    output real  v_membrane         
);

    real v_mem = V_REST;
    real last_time = 0;
    real current_time;
    real delta_t;
    
    logic in_refractory = 0;
    real refractory_end = 0;
    logic waiting_for_ack = 0;

    real g_leak_actual;
    real v_thres_actual;
    
    initial begin
        int seed;
        seed = $urandom();
        g_leak_actual = G_LEAK_TYP * (1.0 + ($dist_normal(seed, 0, 33) / 1000.0));
        v_thres_actual = V_THRES_TYP * (1.0 + ($dist_normal(seed, 0, 33) / 1000.0));
        spike_out = 0;
    end

    always #0.1 begin
        current_time = $realtime;
        delta_t = current_time - last_time;
        
        if (delta_t > 0) begin
            // Asynchronous Handshake Logic
            if (waiting_for_ack) begin
                if (spike_ack) begin
                    spike_out = 0;
                    waiting_for_ack = 0;
                    in_refractory = 1;
                    refractory_end = current_time + REFRACTORY_TIME;
                end
            end else if (in_refractory) begin
                if (current_time >= refractory_end) begin
                    in_refractory = 0;
                    v_mem = V_REST;
                end
            end else begin
                real leak_current;
                real dv;
                real thermal_scaler;
                
                thermal_scaler = 1.0 + ((temp_celsius - 25.0) * 0.05);
                if (thermal_scaler < 0.1) thermal_scaler = 0.1;
                
                leak_current = g_leak_actual * thermal_scaler * (v_mem - V_REST);
                dv = ((i_synaptic - leak_current) / C_MEMBRANE) * (delta_t * 1e-9); 
                
                v_mem = v_mem + dv;
                
                if (v_mem >= v_thres_actual) begin
                    spike_out = 1;
                    v_mem = V_RESET;
                    waiting_for_ack = 1; // Block integration until the network routes the spike
                end else if (v_mem < V_RESET) begin
                    v_mem = V_RESET;
                end
            end
        end
        
        last_time = current_time;
        v_membrane = v_mem;
    end

endmodule
