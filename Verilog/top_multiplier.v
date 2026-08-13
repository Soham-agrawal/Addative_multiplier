module tt_soham_agrawal_logarithmic_multiplier (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // High when the design is enabled
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset_n - active low
);

// Internal Registers
reg [15:0] a;
reg [15:0] b;
reg mode_reg, format_reg, radix_reg; // 1 = FPLM, 0 = CLM; 1 = FP16, 0 = BFLOAT16; 1 = Radix-4, 0 = Full/Non-Radix

// Control Wire Mapping
wire write_mode   = uio_in[0];    // 1 = Write Phase, 0 = Read Phase
wire [1:0] byte_sel = uio_in[2:1]; // 2-bit selector for input/output bytes
wire mode_select    = uio_in[3];  // 1 = FPLM, 0 = CLM
wire format_select  = uio_in[4]; // 1 = FP16 0 = BFLOAT16
wire radix_select   = uio_in[5]; // read mode = 1, write mode = 0

// Combinational Submodule Wires
wire [15:0] result;                       
wire [15:0] prod_comb;

// Bi-directional Pin Configuration
assign uio_oe       = 8'b11000000; // Upper 3 pins as outputs, lower 5 as inputs
assign uio_out[5:0] = 6'b000000;
assign uio_out[6]   = mode_reg; 
assign uio_out[7]   = format_reg;        


multiplier_unified u_mult (
    .num_a(a),
    .num_b(b),
    .format_select(format_reg),
    .radix_select(radix_reg),
    .mode_select(mode_reg),
    .prod(result)
);

// Instantly mux the combinational math result based on the captured mode
assign prod_comb = result;

// Combinational Output Assignments (Active when ena = 1 and in read mode)
assign uo_out = (ena && !write_mode) ? 
                    (byte_sel[0] ? prod_comb[15:8] : prod_comb[7:0]) : 8'b00000000;

// Sequential Logic: Only handles latching the input values
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        a        <= 16'b0;
        b        <= 16'b0;
        mode_reg <= 1'b0;
        format_reg <= 1'b0;
        radix_reg <= 1'b0;
    end else if (ena && write_mode) begin
        // Capture inputs from ui_in when write mode is active
        case (byte_sel)
            2'b00: a[7:0]  <= ui_in;
            2'b01: a[15:8] <= ui_in;
            2'b10: b[7:0]  <= ui_in;
            2'b11: b[15:8] <= ui_in;
        endcase
        mode_reg <= mode_select; // Keep updating selected architecture during configuration
        format_reg <= format_select; // Keep updating format selection during configuration
        radix_reg <= radix_select; // Keep updating radix selection during configuration
    end
end

endmodule
