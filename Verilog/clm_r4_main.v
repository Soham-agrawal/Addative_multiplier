`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 10:47:23 AM
// Design Name: 
// Module Name: clm_r4_main
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


module clm_r4_main(
    input  [31:0] num_a,
    input  [31:0] num_b,
    output [31:0] prod
    );

    // fields
    wire        sign_a, sign_b;
    wire [7:0]  exp_a, exp_b;
    wire [23:0] mant_a, mant_b; // restored mantissa (1.x)
    wire        msb_a, msb_b;
    // coarse mantissa truncation (keep top 12 bits of fraction => 13 bits with implicit 1)
    wire [12:0] mant_a_coarse, mant_b_coarse;
    wire [12:0] mant_shift_a, mant_shift_b;

    // log approximations (coarse)
    wire [13:0] log_approx_a, log_approx_b; // 1 extra bit for msb flag
    wire [15:0] log_sum; // sum of coarse logs (wider)
    wire        msb_p;
    wire [12:0] anti_log_mant_coarse;
    wire [12:0] anti_log_shift_coarse;
    wire [8:0]  exp_sum;
    wire        sign;

    // extract fields
    assign sign_a = num_a[31];
    assign sign_b = num_b[31];
    assign exp_a  = num_a[30:23];
    assign exp_b  = num_b[30:23];
    assign mant_a = {1'b1, num_a[22:0]}; // 1.xxx (24 bits)
    assign mant_b = {1'b1, num_b[22:0]};

    // coarse mantissa: keep top 12 fraction bits (bits 22 down to 11) plus implicit 1 => 13 bits
    assign mant_a_coarse = {1'b1, num_a[22:11]}; // 13 bits
    assign mant_b_coarse = {1'b1, num_b[22:11]};

    // msb indicator (on the top bit of coarse mantissa excluding implicit 1)
    // here msb flag indicates whether mantissa >= 1.5 in coarse representation
    assign msb_a = mant_a_coarse[11]; // original mant's top fraction bit (approx)
    assign msb_b = mant_b_coarse[11];

    // coarse shift by 1 (divide by 2) when msb is set (log domain normalized)
    assign mant_shift_a = (mant_a_coarse >> 1);
    assign mant_shift_b = (mant_b_coarse >> 1);

    // Build a tiny logarithmic approximation (1 bit msb + 13-bit coarse mant)
    assign log_approx_a = msb_a ? {1'b1, mant_shift_a} : {1'b0, mant_a_coarse};
    assign log_approx_b = msb_b ? {1'b1, mant_shift_b} : {1'b0, mant_b_coarse};

    // add in log domain (wider adder)
    assign log_sum = log_approx_a + log_approx_b; // up to ~16 bits

    // detect top bit of sum (whether to renormalize)
    assign msb_p = log_sum[13]; // if top bit set, we have carry > 1 in coarse domain

    // Anti-log: coarse reconstruction: if msb_p then shift low bits left to renormalize
    // we keep 13-bit coarse mantissa after anti-log (implicitly 1.xxx)
    assign anti_log_shift_coarse = (log_sum[12:0] << 1); // coarse multiply by 2
    assign anti_log_mant_coarse  = msb_p ? anti_log_shift_coarse[12:0] : log_sum[12:0];

    // Simple correction bits (very coarse) - a few logical ops to emulate cheap correction
    wire w1, w2, w3, w4;
    assign w1 = ~(msb_a | msb_b);
    assign w2 = ~(msb_a & msb_b);
    assign w3 = (w1 | msb_p);
    assign w4 = ~(w2 & w3);

    // exponent adjust: bias 127
    assign exp_sum = exp_a + exp_b - 127 + w4; // coarse correction via w4

    // sign
    assign sign = sign_a ^ sign_b;

    // pack into IEEE-like single-precision format: sign | exp[7:0] | mantissa[22:0]
    // anti_log_mant_coarse is 13 bits => place in the top bits of mantissa and zero-fill rest (lossy)
    assign prod = {sign, exp_sum[7:0], anti_log_mant_coarse, 10'b0};

endmodule

