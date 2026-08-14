module multiplier_unified (
    input  wire [15:0] num_a,
    input  wire [15:0] num_b,
    input  wire        format_select, // 0 = bfloat16, 1 = FP16
    input  wire        radix_select,  // 0 = Full/Non-Radix, 1 = Radix-4 Truncated
    input wire         mode_select,  // 0 = CLM, 1 = FPLM
    output wire [15:0] prod
);

    // ------------------------------------------------------------------------
    // 1. Unified Input Alignment
    // ------------------------------------------------------------------------
    wire sign_a = num_a[15];
    wire sign_b = num_b[15];

    // Exponent: FP16 zero-extended to 8-bit; bfloat16 passed directly
    wire [7:0] exp_a = format_select ? {3'b000, num_a[14:10]} : num_a[14:7];
    wire [7:0] exp_b = format_select ? {3'b000, num_b[14:10]} : num_b[14:7];

    // Mantissa Fraction: FP16 passed directly (10-bit); bfloat16 left-aligned with 3 zero LSBs
    wire [9:0] raw_frac_a = format_select ? num_a[9:0] : {num_a[6:0], 3'b000};
    wire [9:0] raw_frac_b = format_select ? num_b[9:0] : {num_b[6:0], 3'b000};

    // Dynamic Bias Selection
    wire [7:0] bias = format_select ? 8'd15 : 8'd127;

    // ------------------------------------------------------------------------
    // 2. Radix-4 Programmable Masking (Masks lower 5 bits when active)
    // ------------------------------------------------------------------------
    wire [10:0] mant_a = {1'b1, raw_frac_a};
    wire [10:0] mant_b = {1'b1, raw_frac_b};

    // ------------------------------------------------------------------------
    // 3. Shared FPLM-1 Logarithmic Math Core (10-bit internal fraction)
    // ------------------------------------------------------------------------
    wire msb_a = mant_a[9];
    wire msb_b = mant_b[9];

    wire [10:0] mant_shift_a = (mant_a >> 1);
    wire [10:0] mant_shift_b = (mant_b >> 1);

    wire [10:0] log_approx_a = mode_select? (msb_a ? {1'b1, mant_shift_a[9:0]} : {1'b0, mant_a[9:0]}) : {1'b0, mant_a[9:0]};
    wire [10:0] log_approx_b = mode_select? (msb_b ? {1'b1, mant_shift_b[9:0]} : {1'b0, mant_b[9:0]}) : {1'b0, mant_b[9:0]};

    wire [9:0] log_approx_a_radix4 = log_approx_a[10:1];
    wire [9:0] log_approx_b_radix4 = log_approx_b[10:1];
    //test
    wire [6:0] log_approx_a_radix4_bf16 = log_approx_a[10:4];
    wire [6:0] log_approx_b_radix4_bf16 = log_approx_b[10:4];
    wire [7:0] log_sum_radix4_bf16_preshift = log_approx_a_radix4_bf16 + log_approx_b_radix4_bf16;
    wire [11:0] log_sum_radix4_bf16 = {log_sum_radix4_bf16_preshift[7:0], 4'b0}; // Shift left by 1 for radix-4
    //endtest

    wire [11:0] log_sum_radix2 = log_approx_a + log_approx_b;
    wire [10:0] log_sum_radix4_preshift = log_approx_a_radix4 + log_approx_b_radix4;
    wire [11:0] log_sum_radix4 = {log_sum_radix4_preshift[10:0], 1'b0}; // Shift left by 1 for radix-4

    wire [11:0] log_sum = radix_select ? (format_select ? log_sum_radix4 : log_sum_radix4_bf16) : log_sum_radix2;
    wire        msb_p   = log_sum[10];

    wire [9:0] anti_log_shift = (log_sum[9:0] << 1);
    wire [9:0] anti_log_mant = mode_select ? (msb_p ? anti_log_shift : log_sum[9:0]) : log_sum[9:0];   // CLM: no doubling, msb_p only carries the exponent

    // FPLM-1 Correction logic
    wire [4:1] w;
    assign w[1] = ~(msb_a | msb_b);
    assign w[2] = ~(msb_a & msb_b);
    assign w[3] = (w[1] | msb_p);
    assign w[4] = ~(w[2] & w[3]);

    wire [8:0] exp_sum = mode_select ? (exp_a + exp_b - bias + w[4]) : (exp_a + exp_b - bias + msb_p);
    wire       sign    = sign_a ^ sign_b;

    // ------------------------------------------------------------------------
    // 4. Output Packing Multiplexer
    // ------------------------------------------------------------------------
    assign prod = format_select ? 
                  {sign, exp_sum[4:0], anti_log_mant[9:0]} :      // FP16 Format
                  {sign, exp_sum[7:0], anti_log_mant[9:3]};     // bfloat16 Format

endmodule