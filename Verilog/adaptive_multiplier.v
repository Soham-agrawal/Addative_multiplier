`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 10:50:38 AM
// Design Name: 
// Module Name: adaptive_multiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//   Top-level wrapper that selects between the FPLM-1 (fine, 23-bit mantissa)
//   and CLM-r4 (coarse, 13-bit mantissa) approximate log multipliers.
//
//   This module only INSTANTIATES fplm1_multiplier and clmr4_multiplier -
//   it does not redefine them. Compile this file together with:
//     fplm_1_main.v, fplm1_multiplier.v, clm_r4_main.v, clmr4_multiplier.v
//   Re-declaring those modules here (as the previous version of this file did)
//   causes duplicate-module compile errors and let the two copies of
//   clm_r4_main drift out of sync (the embedded copy had a stale msb_p bit
//   check after its log word was widened from 14 to 16 bits).
//
// Dependencies: 
//   fplm1_multiplier (fplm1_multiplier.v -> fplm_1_main.v)
//   clmr4_multiplier (clmr4_multiplier.v -> clm_r4_main.v)
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Removed duplicate module re-declarations; now instantiates
//                  the shared fplm1_multiplier / clmr4_multiplier modules
//                  from their own files instead of redefining them inline.
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module adaptive_multiplier (
    input         clk,
    input         rst,
    input         mode,         // 0 = FPLM-1, 1 = CLM-r4
    input  [31:0] a,
    input  [31:0] b,
    input         valid_in,
    output [31:0] result,
    output        valid_out
);

    wire [31:0] result_fplm;
    wire [31:0] result_clm;
    wire        valid_fplm;
    wire        valid_clm;

    // Instantiate FPLM-1 wrapper (defined in fplm1_multiplier.v / fplm_1_main.v)
    fplm1_multiplier u_fplm1 (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .valid_in(valid_in),
        .result(result_fplm),
        .valid_out(valid_fplm)
    );

    // Instantiate CLM-r4 wrapper (defined in clmr4_multiplier.v / clm_r4_main.v)
    clmr4_multiplier u_clmr4 (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .valid_in(valid_in),
        .result(result_clm),
        .valid_out(valid_clm)
    );

    // Mode-based output selection
    assign result    = (mode == 1'b0) ? result_fplm : result_clm;
    assign valid_out = (mode == 1'b0) ? valid_fplm  : valid_clm;

endmodule
