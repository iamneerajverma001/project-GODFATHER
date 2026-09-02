`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: 1S1R Memristor Crossbar with Parasitic IR Drop
// ==============================================================================

module memristor_crossbar #(
    parameter int N_PRE = 64,
    parameter int N_POST = 64,
    parameter real G_MIN = 1e-9,  
    parameter real G_MAX = 100e-9,
    parameter real V_SET = 0.3,    // Lowered for subthreshold 1.0V logic
    parameter real V_RESET = -0.3,
    parameter real V_SELECTOR = 0.5,
    parameter real R_WIRE = 0.1,
    parameter int TILE_X = 0,
    parameter int TILE_Y = 0,
    parameter int TILE_Z = 0
)(
    input  real v_pre [0:N_PRE-1],   
    input  real v_post [0:N_POST-1], 
    input  real error_gradient,      // The Holy Grail: Global/Local Error routing for 3-factor supervised learning
    output real i_out [0:N_POST-1],
    
    // Cure 4: HBM DMA Paging Interface (Background weight swapping for trillion-parameter models)
    input  logic        dma_we,
    input  logic [15:0] dma_row,
    input  logic [15:0] dma_col,
    input  real         dma_wdata
);

    real conductance [0:N_PRE-1][0:N_POST-1];

    initial begin
        // The NeuroForge SDK Bridge: Load physical initialized weights if present
        int fd;
        int status;
        string filename;
        
        filename = $sformatf("sdk/build/TILE_%0d_%0d_%0d_init.mem", TILE_X, TILE_Y, TILE_Z);
        fd = $fopen(filename, "r");
        
        if (fd) begin
            $display("Memristor Array [%0d][%0d][%0d]: Loading NeuroForge physical weights from %s", TILE_X, TILE_Y, TILE_Z, filename);
            for (int i = 0; i < N_PRE; i++) begin
                for (int j = 0; j < N_POST; j++) begin
                    status = $fscanf(fd, "%e", conductance[i][j]);
                end
            end
            $fclose(fd);
        end else begin
            $display("Memristor Array: No SDK init found. Using fallback stochastic boot.");
            for (int i = 0; i < N_PRE; i++) begin
                for (int j = 0; j < N_POST; j++) begin
                    conductance[i][j] = G_MIN + ((G_MAX - G_MIN) * 0.1 * ($urandom_range(0, 100) / 100.0));
                end
            end
        end
    end

    real current_time, last_time, delta_t;
    initial last_time = 0;

    always #0.1 begin
        current_time = $realtime;
        delta_t = current_time - last_time;

        if (delta_t > 0) begin
            for (int j = 0; j < N_POST; j++) begin
                real column_current;
                column_current = 0.0;
                
                for (int i = 0; i < N_PRE; i++) begin
                    real v_diff;
                    real cross_current;
                    real effective_v_diff;
                    real delta_g;
                    real v_pre_local;
                    real v_post_local;
                    
                    // Parasitic IR drop along the wire (approximated based on depth in matrix)
                    // Further down the wire = more resistance
                    v_pre_local = v_pre[i] * (1.0 - (j * R_WIRE * 0.001)); 
                    v_post_local = v_post[j] * (1.0 - (i * R_WIRE * 0.001));
                    
                    v_diff = v_pre_local - v_post_local;
                    
                    // 1S1R Selector Physics (Highly non-linear diode)
                    // Blocks sneak paths if v_diff is below V_SELECTOR
                    if (v_diff > V_SELECTOR) begin
                        effective_v_diff = v_diff - V_SELECTOR;
                    end else if (v_diff < -V_SELECTOR) begin
                        effective_v_diff = v_diff + V_SELECTOR;
                    end else begin
                        effective_v_diff = 0.0;
                    end
                    
                    cross_current = effective_v_diff * conductance[i][j];
                    column_current += cross_current;
                    
                    // -------------------------------------------------------------
                    // THE HOLY GRAIL: 3-Factor R-STDP (Eligibility Propagation)
                    // -------------------------------------------------------------
                    // STDP generates an eligibility trace based on local voltage gradients.
                    // The Global Error Gradient dictates if this trace turns into LTP (learning)
                    // or LTD (unlearning). If error_gradient == 0, the brain is in inference mode.
                    if (error_gradient != 0.0) begin
                        if (effective_v_diff > V_SET) begin
                            // Eligibility trace is positive (Pre fired before Post)
                            delta_g = (G_MAX - conductance[i][j]) * 1e-3 * delta_t * ((effective_v_diff / V_SET) * (effective_v_diff / V_SET)); 
                            conductance[i][j] += (delta_g * error_gradient); // Modulate by Error
                        end else if (effective_v_diff < V_RESET) begin
                            // Eligibility trace is negative (Post fired before Pre)
                            delta_g = (conductance[i][j] - G_MIN) * 1e-3 * delta_t * ((-effective_v_diff / -V_RESET) * (-effective_v_diff / -V_RESET));
                            conductance[i][j] -= (delta_g * error_gradient); // Modulate by Error
                        end
                        // Clamp to physical bounds
                        if (conductance[i][j] > G_MAX) conductance[i][j] = G_MAX;
                        if (conductance[i][j] < G_MIN) conductance[i][j] = G_MIN;
                    end
                end
                i_out[j] = column_current;
            end
        end
        last_time = current_time;
    end
    
    // HBM DMA Paging Logic
    always @(*) begin
        if (dma_we) begin
            if (dma_row < N_PRE && dma_col < N_POST) begin
                conductance[dma_row][dma_col] = dma_wdata;
            end
        end
    end

endmodule
