`timescale 1ns / 1ps

module tb_godfather_core();

    // Analog Inputs
    real sensor_voltages [0:63];
    
    // Asynchronous Outputs
    logic [15:0] aer_addr;
    logic        aer_req;
    logic        aer_ack;

    // Instantiate the GODFATHER core
    godfather_top #(
        .N_SENSORS(64),
        .N_NEURONS(64)
    ) dut (
        .sensor_voltages(sensor_voltages),
        .out_aer_addr(aer_addr),
        .out_aer_req(aer_req),
        .out_aer_ack(aer_ack)
    );

    // Asynchronous Acknowledge Generation
    always @(posedge aer_req) begin
        #1; // 1ns delay for receiving side processing
        aer_ack = 1;
        @(negedge aer_req);
        #1;
        aer_ack = 0;
    end

    initial begin
        $display("\n=======================================================");
        $display("   PROJECT GODFATHER: MIXED-SIGNAL PHYSICS SIMULATION");
        $display("=======================================================\n");

        for (int i = 0; i < 64; i++) sensor_voltages[i] = 0.0;

        #10;
        $display("[Time: %0t ns] Injecting 1.0V analog stimulus on Sensor [0]...", $realtime);
        sensor_voltages[0] = 1.0;
        
        #50;
        $display("[Time: %0t ns] Injecting 1.0V analog stimulus on Sensor [15]...", $realtime);
        sensor_voltages[15] = 1.0;
        
        #200;
        $display("[Time: %0t ns] Simulation Complete.", $realtime);
        $display("\n=======================================================\n");
        $finish;
    end

    // The Telemetry Bridge: Dump Memristor Conductance for Python Visualization
    int fd;
    initial begin
        fd = $fopen("brain_telemetry.csv", "w");
        forever #10.0 begin
            for (int i = 0; i < 64; i++) begin
                for (int j = 0; j < 64; j++) begin
                    $fwrite(fd, "%e,", dut.cognitive_matrix.conductance[i][j]);
                end
                $fwrite(fd, "\n");
            end
            $fwrite(fd, "===\n"); // Time-step separator
        end
    end
    
endmodule
