`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 10:43:18 AM
// Design Name: 
// Module Name: fplm1_multiplier
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


module fplm1_multiplier (
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

    // Instantiate the combinational FPLM-1 core
    fplm_1_main u_fplm (
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

