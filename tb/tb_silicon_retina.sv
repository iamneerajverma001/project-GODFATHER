`timescale 1ns / 1ps

module tb_silicon_retina();

    parameter int RES_X = 16;
    parameter int RES_Y = 16;
    
    real pixel_illumination [0:RES_X-1][0:RES_Y-1];
    
    logic [31:0] aer_data;
    logic        aer_req;
    logic        aer_ack;
    
    silicon_retina #(
        .RES_X(RES_X),
        .RES_Y(RES_Y),
        .THRESHOLD_ON(0.5),
        .THRESHOLD_OFF(-0.5)
    ) dut (
        .pixel_illumination(pixel_illumination),
        .out_aer_data(aer_data),
        .out_aer_req(aer_req),
        .out_aer_ack(aer_ack)
    );
    
    // Auto-acknowledge AER spikes
    always @(posedge aer_req) begin
        #0.5; // Simulate receiver delay
        aer_ack = 1;
        
        // Log the spike
        $display("[Time: %0t ns] RETINA SPIKE -> X: %0d, Y: %0d, Polarity: %s", 
                 $time, aer_data[31:24], aer_data[23:16], aer_data[0] ? "ON (Brighter)" : "OFF (Darker)");
                 
        @(negedge aer_req);
        #0.5;
        aer_ack = 0;
    end

    initial begin
        $display("\n=======================================================");
        $display("   JARVIS CORP: SILICON RETINA (DVS) EVENT TEST");
        $display("=======================================================\n");

        // Set baseline darkness
        for (int x = 0; x < RES_X; x++) begin
            for (int y = 0; y < RES_Y; y++) begin
                pixel_illumination[x][y] = 0.001;
            end
        end
        
        #10;
        
        $display("\n---> Action: Moving a bright bar horizontally across the retina (Y=5 to Y=8)...\n");
        
        // Simulate a bright object moving from left to right
        for (int frame = 0; frame < RES_X; frame++) begin
            
            // Advance time
            #5.0;
            
            // Update illumination
            for (int x = 0; x < RES_X; x++) begin
                for (int y = 0; y < RES_Y; y++) begin
                    
                    // The bright bar is 2 pixels wide
                    if (y >= 5 && y <= 8 && x >= frame && x < frame + 2) begin
                        pixel_illumination[x][y] = 2.0; // Bright
                    end else begin
                        pixel_illumination[x][y] = 0.001; // Dark
                    end
                    
                end
            end
        end
        
        #50;
        $display("\n=======================================================");
        $display("   TEST COMPLETE: Observe the asynchronous edge detection.");
        $display("=======================================================\n");
        $finish;
    end

endmodule
