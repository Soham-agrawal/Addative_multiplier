`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 10:48:46 AM
// Design Name: 
// Module Name: clmr4_multiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clmr4_multiplier (
    input         clk,
    input         rst,
    input  [31:0] a,
    input  [31:0] b,
    input         valid_in,
    output [31:0] result,
    output        valid_out
);

    wire [31:0] prod_core;
    reg  [31:0] result_reg;
    reg         valid_reg;

    // Instantiate the combinational CLM-r4 core
    clm_r4_main u_clm (
        .num_a(a),
        .num_b(b),
        .prod(prod_core)
    );

    // Register result and valid_out (1-cycle latency)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result_reg <= 32'd0;
            valid_reg  <= 1'b0;
        end else begin
            result_reg <= prod_core;
            valid_reg  <= valid_in;
        end
    end

    assign result    = result_reg;
    assign valid_out = valid_reg;

endmodule

