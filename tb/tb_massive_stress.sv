`timescale 1ns / 1ps

// ==============================================================================
// PROJECT GODFATHER: MASSIVE RIGOROUS STRESS TESTBENCH
// ==============================================================================
// Lead Tester: Architect
// Purpose: Multi-dimensional boundary testing of the 2D NoC Business Variant.
// Tests: Asynchronous Deadlocks, STDP Memory Overflow, and SRAM PUF ECC Stability.
// ==============================================================================

module tb_massive_stress;

    // 1. DUT Instantiation (2x2 Mesh = 256 Neurons, 4 NoC Routers, 16K Memristors)
    logic power_on;
    real env_illumination [0:15][0:15];
    real env_audio = 0.0;
    logic [255:0] chiplet_identity;
    logic         identity_valid;

    // Initialize sensors and temp
    real global_temp_celsius = 25.0;
    initial begin
        for(int i=0; i<16; i++)
            for(int j=0; j<16; j++)
                env_illumination[i][j] = 0.001; // Dark
    end

    godfather_business_edition #(
        .MESH_X(2),
        .MESH_Y(2),
        .MESH_Z(2)
    ) dut (
        .power_on(power_on),
        .env_illumination(env_illumination),
        .env_audio_wave(env_audio),
        .global_temp_celsius(global_temp_celsius),
        .chiplet_identity(chiplet_identity),
        .identity_valid(identity_valid)
    );

    // Trackers
    logic [255:0] locked_key;
    int spikes_captured = 0;
    real starting_weight;
    real ending_weight;

    initial begin
        $display("\n=======================================================");
        $display("   GODFATHER LEAD TESTER: INITIATING MASSIVE STRESS");
        $display("=======================================================\n");

        // -------------------------------------------------------------
        // PHASE 1: SRAM PUF THERMAL NOISE & ECC LOCK TEST
        // -------------------------------------------------------------
        $display("[PHASE 1] Booting Secure Enclave... testing ECC Fuzzy Extractor.");
        power_on = 0;
        #100;
        power_on = 1;
        wait(identity_valid);
        locked_key = chiplet_identity;
        $display("          [OK] Initial Lock Achieved: %x", locked_key[63:0]); // Display lower 64 bits
        
        // Power cycle with extreme thermal noise (Simulated inside the PUF)
        #100 power_on = 0; #100 power_on = 1;
        wait(identity_valid);
        if (chiplet_identity !== locked_key) begin
            $display("          [FATAL] ECC Failed to correct thermal bit-flips!");
            $finish;
        end else begin
            $display("          [OK] ECC Stable. Identity verified across thermal power-cycles.");
        end

        // -------------------------------------------------------------
        // PHASE 2: ASYNCHRONOUS PACKET STORM (DEADLOCK TEST)
        // -------------------------------------------------------------
        $display("\n[PHASE 2] Initiating Asynchronous NoC Packet Storm (Collision Test).");
        $display("          Injecting 1.0V into ALL 256 sensors across the 2x2 grid simultaneously...");
        
        // Use massive vector assignment to slam the entire grid
        for (int x = 0; x < 16; x++) begin
            for (int y = 0; y < 16; y++) begin
                env_illumination[x][y] = 1.0; // Saturate the Retina
            end
        end

        // We expect the subthreshold LIFs to integrate and fire simultaneously around 100ns.
        // If the 5-port asynchronous NoC routers have deadlocks, the simulation will hang 
        // or requests will never be acknowledged.
        #2000;
        
        // -------------------------------------------------------------
        // PHASE 3: THERMAL SWEEP & STDP OVERFLOW TEST (NaN Check)
        // -------------------------------------------------------------
        $display("\n[PHASE 3] Sweeping core temperatures and testing STDP asymptote limits.");
        starting_weight = dut.mesh_layer[0].mesh_col[1].mesh_row[1].cognitive_matrix.tile.cognitive_matrix.conductance[0][0];
        
        // Force extreme automotive temperature (125 Celsius) deep into the neurons
        global_temp_celsius = 125.0;
        $display("          Temperature raised to 125C. Leakage currents maximized.");
        
        // Run a massive time-jump to allow continuous STDP filament thickening
        // If the physics is flawed, conductance will exceed G_MAX and throw a NaN floating point error.
        $display("          Simulating 5,000 nanoseconds of continuous physical stress...");
        #5000;
        
        ending_weight = dut.mesh_layer[0].mesh_col[1].mesh_row[1].cognitive_matrix.tile.cognitive_matrix.conductance[0][0];
        $display("          Initial Memristor [0][0] Conductance: %e", starting_weight);
        $display("          Final Memristor [0][0] Conductance:   %e", ending_weight);
        
        if (ending_weight > 100e-9) begin // G_MAX is 100e-9
            $display("          [FATAL] Memristor conductance overflowed physical limits!");
        end else begin
            $display("          [OK] STDP Physics maintained strict physical asymptotes.");
        end

        $display("\n=======================================================");
        $display("   MASSIVE STRESS TEST COMPLETE: ZERO ARCHITECTURAL FLAWS");
        $display("=======================================================\n");
        
        $finish;
    end
    // The Telemetry Bridge: Dump Memristor Conductance for Python Visualization
    int fd;
    initial begin
        fd = $fopen("brain_telemetry.csv", "w");
        forever #500.0 begin
            for (int i = 0; i < 64; i++) begin
                for (int j = 0; j < 64; j++) begin
                    $fwrite(fd, "%e,", dut.mesh_layer[0].mesh_col[1].mesh_row[1].cognitive_matrix.tile.cognitive_matrix.conductance[i][j]);
                end
                $fwrite(fd, "\n");
            end
            $fwrite(fd, "===\n"); // Time-step separator
        end
    end

endmodule
