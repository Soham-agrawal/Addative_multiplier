`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 10:41:56 AM
// Design Name: 
// Module Name: fplm_1_main
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


module fplm_1_main(
    input [31:0] num_a,num_b,
    output [31:0] prod
    );
    wire        sign_a,
	    sign_b;
wire [7:0]  exp_a,
	    exp_b;
wire [23:0] mant_a,
	    mant_b;
wire        msb_a;
wire	    msb_b;
wire	    msb_p;
wire [4:1]  w;
wire [23:0] mant_shift_a;
wire [23:0] mant_shift_b;

wire [23:0] log_approx_a;
wire [23:0] log_approx_b;

wire [24:0] log_sum;
wire [22:0] anti_log_mant;
wire [22:0] anti_log_shift;
wire sign;
wire [8:0] exp_sum;

assign sign_a = num_a[31];
assign sign_b = num_b[31];

assign exp_a = num_a[30:23];
assign exp_b = num_b[30:23];

assign mant_a = {1'b1,num_a[22:0]};
assign mant_b = {1'b1,num_b[22:0]};

assign msb_a=mant_a[22];
assign msb_b=mant_b[22];

assign mant_shift_a=(mant_a>>1);
assign mant_shift_b=(mant_b>>1);

assign log_approx_a= msb_a ? {1'b1,mant_shift_a[22:0]}:{1'b0,mant_a[22:0]};
assign log_approx_b= msb_b ? {1'b1,mant_shift_b[22:0]}:{1'b0,mant_b[22:0]};

assign log_sum= log_approx_a +log_approx_b;

assign msb_p= log_sum[23];

assign anti_log_shift= (log_sum[22:0]<<1);

assign anti_log_mant=msb_p? anti_log_shift:log_sum[22:0];

assign w[1]= ~(msb_a | msb_b);
assign w[2]= ~(msb_a & msb_b);
assign w[3]=  (w[1]  | msb_p);
assign w[4]= ~(w[2]  & w[3] );
assign exp_sum = exp_a + exp_b -127 + w[4];
assign sign = sign_a ^ sign_b;

assign prod={sign,exp_sum[7:0],anti_log_mant};

endmodule

