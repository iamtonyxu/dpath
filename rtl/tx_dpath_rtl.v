module tx_dpath_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter TFIR_MAX_TAPS = 80
)(
    input                          clk,
    input                          rst_n,
    input                          in_valid,
    output                         in_ready,
    input  signed [DATA_W-1:0]     in_i,
    input  signed [DATA_W-1:0]     in_q,
    input                          cfg_path_int5,
    input                          cfg_tfir_bypass,
    input        [2:0]             cfg_tfir_interp,
    input        [1:0]             cfg_tfir_gain_sel,
    input        [6:0]             cfg_tfir_tap_count,
    input                          cfg_thb1_bypass,
    input                          cfg_thb2_bypass,
    input                          cfg_thb3_bypass,
    input                          cfg_int5_bypass,
    input                          coeff_wr_en,
    input        [6:0]             coeff_wr_addr,
    input  signed [COEFF_W-1:0]    coeff_wr_data,
    output reg                     out_valid,
    output reg signed [DATA_W-1:0] out_i,
    output reg signed [DATA_W-1:0] out_q
);

    localparam S_IDLE   = 3'd0;
    localparam S_TFIR   = 3'd1;
    localparam S_THB1   = 3'd2;
    localparam S_THB2   = 3'd3;
    localparam S_THB3   = 3'd4;
    localparam S_INT5   = 3'd5;
    localparam S_OUTPUT = 3'd6;

    integer idx;

    reg [2:0] state;

    reg path_int5_d;
    reg tfir_bypass_d;
    reg [2:0] tfir_interp_d;
    reg [1:0] tfir_gain_sel_d;
    reg [6:0] tfir_tap_count_d;
    reg thb1_bypass_d;
    reg thb2_bypass_d;
    reg thb3_bypass_d;
    reg int5_bypass_d;

    reg signed [DATA_W-1:0] input_sample_i;
    reg signed [DATA_W-1:0] input_sample_q;

    reg [5:0] tfir_expected;
    reg [5:0] thb1_expected;
    reg [5:0] thb2_expected;
    reg [5:0] thb3_expected;
    reg [5:0] int5_expected;
    reg [5:0] final_expected;

    reg [5:0] tfir_feed_idx;
    reg [5:0] tfir_out_idx;
    reg [5:0] thb1_feed_idx;
    reg [5:0] thb1_out_idx;
    reg [5:0] thb2_feed_idx;
    reg [5:0] thb2_out_idx;
    reg [5:0] thb3_feed_idx;
    reg [5:0] thb3_out_idx;
    reg [5:0] int5_feed_idx;
    reg [5:0] int5_out_idx;
    reg [5:0] output_idx;

    reg signed [DATA_W-1:0] tfir_buf_i [0:3];
    reg signed [DATA_W-1:0] tfir_buf_q [0:3];
    reg signed [DATA_W-1:0] thb1_buf_i [0:7];
    reg signed [DATA_W-1:0] thb1_buf_q [0:7];
    reg signed [DATA_W-1:0] thb2_buf_i [0:15];
    reg signed [DATA_W-1:0] thb2_buf_q [0:15];
    reg signed [DATA_W-1:0] thb3_buf_i [0:31];
    reg signed [DATA_W-1:0] thb3_buf_q [0:31];
    reg signed [DATA_W-1:0] int5_buf_i [0:39];
    reg signed [DATA_W-1:0] int5_buf_q [0:39];

    wire tfir_in_valid;
    wire signed [DATA_W-1:0] tfir_in_i;
    wire signed [DATA_W-1:0] tfir_in_q;
    wire tfir_in_ready;
    wire tfir_out_valid;
    wire signed [DATA_W-1:0] tfir_out_i;
    wire signed [DATA_W-1:0] tfir_out_q;

    wire thb1_in_valid;
    wire signed [DATA_W-1:0] thb1_in_i;
    wire signed [DATA_W-1:0] thb1_in_q;
    wire thb1_in_ready;
    wire thb1_out_valid;
    wire signed [DATA_W-1:0] thb1_out_i;
    wire signed [DATA_W-1:0] thb1_out_q;

    wire thb2_in_valid;
    wire signed [DATA_W-1:0] thb2_in_i;
    wire signed [DATA_W-1:0] thb2_in_q;
    wire thb2_in_ready;
    wire thb2_out_valid;
    wire signed [DATA_W-1:0] thb2_out_i;
    wire signed [DATA_W-1:0] thb2_out_q;

    wire thb3_in_valid;
    wire signed [DATA_W-1:0] thb3_in_i;
    wire signed [DATA_W-1:0] thb3_in_q;
    wire thb3_in_ready;
    wire thb3_out_valid;
    wire signed [DATA_W-1:0] thb3_out_i;
    wire signed [DATA_W-1:0] thb3_out_q;

    wire int5_in_valid;
    wire signed [DATA_W-1:0] int5_in_i;
    wire signed [DATA_W-1:0] int5_in_q;
    wire int5_in_ready;
    wire int5_out_valid;
    wire signed [DATA_W-1:0] int5_out_i;
    wire signed [DATA_W-1:0] int5_out_q;

    function [5:0] tfir_output_count;
        input bypass;
        input [2:0] interp;
        begin
            if (bypass) begin
                tfir_output_count = 6'd1;
            end else begin
                case (interp)
                    3'd2: tfir_output_count = 6'd2;
                    3'd4: tfir_output_count = 6'd4;
                    default: tfir_output_count = 6'd1;
                endcase
            end
        end
    endfunction

    assign in_ready = (state == S_IDLE);

    assign tfir_in_valid = (state == S_TFIR) && (tfir_feed_idx < 6'd1);
    assign tfir_in_i = input_sample_i;
    assign tfir_in_q = input_sample_q;

    assign thb1_in_valid = (state == S_THB1) && (thb1_feed_idx < tfir_expected);
    assign thb1_in_i = tfir_buf_i[thb1_feed_idx];
    assign thb1_in_q = tfir_buf_q[thb1_feed_idx];

    assign thb2_in_valid = (state == S_THB2) && (thb2_feed_idx < thb1_expected);
    assign thb2_in_i = thb1_buf_i[thb2_feed_idx];
    assign thb2_in_q = thb1_buf_q[thb2_feed_idx];

    assign thb3_in_valid = (state == S_THB3) && (thb3_feed_idx < thb2_expected);
    assign thb3_in_i = thb2_buf_i[thb3_feed_idx];
    assign thb3_in_q = thb2_buf_q[thb3_feed_idx];

    assign int5_in_valid = (state == S_INT5) && (int5_feed_idx < thb1_expected);
    assign int5_in_i = thb1_buf_i[int5_feed_idx];
    assign int5_in_q = thb1_buf_q[int5_feed_idx];

    tfir_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(TFIR_MAX_TAPS),
        .TAP_ADDR_W(7)
    ) u_tfir (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(tfir_in_valid),
        .in_ready(tfir_in_ready),
        .in_i(tfir_in_i),
        .in_q(tfir_in_q),
        .cfg_bypass(tfir_bypass_d),
        .cfg_interp(tfir_interp_d),
        .cfg_gain_sel(tfir_gain_sel_d),
        .cfg_tap_count(tfir_tap_count_d),
        .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data),
        .out_valid(tfir_out_valid),
        .out_i(tfir_out_i),
        .out_q(tfir_out_q)
    );

    thb1_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(71)
    ) u_thb1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(thb1_in_valid),
        .in_ready(thb1_in_ready),
        .in_i(thb1_in_i),
        .in_q(thb1_in_q),
        .cfg_bypass(thb1_bypass_d),
        .out_valid(thb1_out_valid),
        .out_i(thb1_out_i),
        .out_q(thb1_out_q)
    );

    thb2_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(7)
    ) u_thb2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(thb2_in_valid),
        .in_ready(thb2_in_ready),
        .in_i(thb2_in_i),
        .in_q(thb2_in_q),
        .cfg_bypass(thb2_bypass_d),
        .out_valid(thb2_out_valid),
        .out_i(thb2_out_i),
        .out_q(thb2_out_q)
    );

    thb3_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(5)
    ) u_thb3 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(thb3_in_valid),
        .in_ready(thb3_in_ready),
        .in_i(thb3_in_i),
        .in_q(thb3_in_q),
        .cfg_bypass(thb3_bypass_d),
        .out_valid(thb3_out_valid),
        .out_i(thb3_out_i),
        .out_q(thb3_out_q)
    );

    int5_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(67)
    ) u_int5 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(int5_in_valid),
        .in_ready(int5_in_ready),
        .in_i(int5_in_i),
        .in_q(int5_in_q),
        .cfg_bypass(int5_bypass_d),
        .out_valid(int5_out_valid),
        .out_i(int5_out_i),
        .out_q(int5_out_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};

            path_int5_d <= 1'b0;
            tfir_bypass_d <= 1'b0;
            tfir_interp_d <= 3'd1;
            tfir_gain_sel_d <= 2'd1;
            tfir_tap_count_d <= 7'd20;
            thb1_bypass_d <= 1'b0;
            thb2_bypass_d <= 1'b0;
            thb3_bypass_d <= 1'b0;
            int5_bypass_d <= 1'b0;

            input_sample_i <= {DATA_W{1'b0}};
            input_sample_q <= {DATA_W{1'b0}};

            tfir_expected <= 6'd0;
            thb1_expected <= 6'd0;
            thb2_expected <= 6'd0;
            thb3_expected <= 6'd0;
            int5_expected <= 6'd0;
            final_expected <= 6'd0;

            tfir_feed_idx <= 6'd0;
            tfir_out_idx <= 6'd0;
            thb1_feed_idx <= 6'd0;
            thb1_out_idx <= 6'd0;
            thb2_feed_idx <= 6'd0;
            thb2_out_idx <= 6'd0;
            thb3_feed_idx <= 6'd0;
            thb3_out_idx <= 6'd0;
            int5_feed_idx <= 6'd0;
            int5_out_idx <= 6'd0;
            output_idx <= 6'd0;

            for (idx = 0; idx < 4; idx = idx + 1) begin
                tfir_buf_i[idx] <= {DATA_W{1'b0}};
                tfir_buf_q[idx] <= {DATA_W{1'b0}};
            end
            for (idx = 0; idx < 8; idx = idx + 1) begin
                thb1_buf_i[idx] <= {DATA_W{1'b0}};
                thb1_buf_q[idx] <= {DATA_W{1'b0}};
            end
            for (idx = 0; idx < 16; idx = idx + 1) begin
                thb2_buf_i[idx] <= {DATA_W{1'b0}};
                thb2_buf_q[idx] <= {DATA_W{1'b0}};
            end
            for (idx = 0; idx < 32; idx = idx + 1) begin
                thb3_buf_i[idx] <= {DATA_W{1'b0}};
                thb3_buf_q[idx] <= {DATA_W{1'b0}};
            end
            for (idx = 0; idx < 40; idx = idx + 1) begin
                int5_buf_i[idx] <= {DATA_W{1'b0}};
                int5_buf_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        input_sample_i <= in_i;
                        input_sample_q <= in_q;

                        path_int5_d <= cfg_path_int5;
                        tfir_bypass_d <= cfg_tfir_bypass;
                        tfir_interp_d <= cfg_tfir_interp;
                        tfir_gain_sel_d <= cfg_tfir_gain_sel;
                        tfir_tap_count_d <= cfg_tfir_tap_count;
                        thb1_bypass_d <= cfg_thb1_bypass;
                        thb2_bypass_d <= cfg_thb2_bypass;
                        thb3_bypass_d <= cfg_thb3_bypass;
                        int5_bypass_d <= cfg_int5_bypass;

                        tfir_expected <= tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp);
                        thb1_expected <= cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1);
                        thb2_expected <= cfg_thb2_bypass ? (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) : ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) << 1);
                        thb3_expected <= cfg_thb3_bypass ? (cfg_thb2_bypass ? (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) : ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) << 1)) : ((cfg_thb2_bypass ? (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) : ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) << 1)) << 1);
                        int5_expected <= (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) * 5;
                        final_expected <= cfg_path_int5 ? ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) * 5) : (cfg_thb3_bypass ? (cfg_thb2_bypass ? (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) : ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) << 1)) : ((cfg_thb2_bypass ? (cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) : ((cfg_thb1_bypass ? tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) : (tfir_output_count(cfg_tfir_bypass, cfg_tfir_interp) << 1)) << 1)) << 1));

                        tfir_feed_idx <= 6'd0;
                        tfir_out_idx <= 6'd0;
                        thb1_feed_idx <= 6'd0;
                        thb1_out_idx <= 6'd0;
                        thb2_feed_idx <= 6'd0;
                        thb2_out_idx <= 6'd0;
                        thb3_feed_idx <= 6'd0;
                        thb3_out_idx <= 6'd0;
                        int5_feed_idx <= 6'd0;
                        int5_out_idx <= 6'd0;
                        output_idx <= 6'd0;

                        state <= S_TFIR;
                    end
                end

                S_TFIR: begin
                    if (tfir_in_valid && tfir_in_ready) begin
                        tfir_feed_idx <= tfir_feed_idx + 6'd1;
                    end

                    if (tfir_out_valid) begin
                        tfir_buf_i[tfir_out_idx] <= tfir_out_i;
                        tfir_buf_q[tfir_out_idx] <= tfir_out_q;
                        tfir_out_idx <= tfir_out_idx + 6'd1;

                        if ((tfir_feed_idx == 6'd1) && (tfir_out_idx == tfir_expected - 6'd1)) begin
                            thb1_feed_idx <= 6'd0;
                            thb1_out_idx <= 6'd0;
                            state <= S_THB1;
                        end
                    end
                end

                S_THB1: begin
                    if (thb1_in_valid && thb1_in_ready) begin
                        thb1_feed_idx <= thb1_feed_idx + 6'd1;
                    end

                    if (thb1_out_valid) begin
                        thb1_buf_i[thb1_out_idx] <= thb1_out_i;
                        thb1_buf_q[thb1_out_idx] <= thb1_out_q;
                        thb1_out_idx <= thb1_out_idx + 6'd1;

                        if ((thb1_feed_idx == tfir_expected) && (thb1_out_idx == thb1_expected - 6'd1)) begin
                            if (path_int5_d) begin
                                int5_feed_idx <= 6'd0;
                                int5_out_idx <= 6'd0;
                                state <= S_INT5;
                            end else begin
                                thb2_feed_idx <= 6'd0;
                                thb2_out_idx <= 6'd0;
                                state <= S_THB2;
                            end
                        end
                    end
                end

                S_THB2: begin
                    if (thb2_in_valid && thb2_in_ready) begin
                        thb2_feed_idx <= thb2_feed_idx + 6'd1;
                    end

                    if (thb2_out_valid) begin
                        thb2_buf_i[thb2_out_idx] <= thb2_out_i;
                        thb2_buf_q[thb2_out_idx] <= thb2_out_q;
                        thb2_out_idx <= thb2_out_idx + 6'd1;

                        if ((thb2_feed_idx == thb1_expected) && (thb2_out_idx == thb2_expected - 6'd1)) begin
                            thb3_feed_idx <= 6'd0;
                            thb3_out_idx <= 6'd0;
                            state <= S_THB3;
                        end
                    end
                end

                S_THB3: begin
                    if (thb3_in_valid && thb3_in_ready) begin
                        thb3_feed_idx <= thb3_feed_idx + 6'd1;
                    end

                    if (thb3_out_valid) begin
                        thb3_buf_i[thb3_out_idx] <= thb3_out_i;
                        thb3_buf_q[thb3_out_idx] <= thb3_out_q;
                        thb3_out_idx <= thb3_out_idx + 6'd1;

                        if ((thb3_feed_idx == thb2_expected) && (thb3_out_idx == thb3_expected - 6'd1)) begin
                            output_idx <= 6'd0;
                            state <= S_OUTPUT;
                        end
                    end
                end

                S_INT5: begin
                    if (int5_in_valid && int5_in_ready) begin
                        int5_feed_idx <= int5_feed_idx + 6'd1;
                    end

                    if (int5_out_valid) begin
                        int5_buf_i[int5_out_idx] <= int5_out_i;
                        int5_buf_q[int5_out_idx] <= int5_out_q;
                        int5_out_idx <= int5_out_idx + 6'd1;

                        if ((int5_feed_idx == thb1_expected) && (int5_out_idx == int5_expected - 6'd1)) begin
                            output_idx <= 6'd0;
                            state <= S_OUTPUT;
                        end
                    end
                end

                S_OUTPUT: begin
                    out_valid <= 1'b1;
                    if (path_int5_d) begin
                        out_i <= int5_buf_i[output_idx];
                        out_q <= int5_buf_q[output_idx];
                    end else begin
                        out_i <= thb3_buf_i[output_idx];
                        out_q <= thb3_buf_q[output_idx];
                    end

                    if (output_idx == final_expected - 6'd1) begin
                        state <= S_IDLE;
                    end else begin
                        output_idx <= output_idx + 6'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule