module rx_dpath_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter PFIR_MAX_TAPS = 72,
    parameter MAX_INPUT_SAMPLES = 256,
    parameter MAX_BUFFER_SAMPLES = 384
)(
    input                           clk,
    input                           rst_n,
    input                           in_valid,
    output                          in_ready,
    input  signed [DATA_W-1:0]      in_i,
    input  signed [DATA_W-1:0]      in_q,
    input         [15:0]            cfg_input_count,
    input                           cfg_front_path_fir_chain,
    input                           cfg_dec5_bypass,
    input                           cfg_fir2_bypass,
    input                           cfg_fir1_bypass,
    input                           cfg_rhb2_bypass,
    input                           cfg_rhb1_mode_lp,
    input                           cfg_hr_bypass,
    input                           cfg_lp_bypass,
    input                           cfg_pfir_bypass,
    input         [2:0]             cfg_pfir_decim,
    input         [1:0]             cfg_pfir_gain_sel,
    input         [6:0]             cfg_pfir_tap_count,
    input                           coeff_wr_en,
    input         [6:0]             coeff_wr_addr,
    input  signed [COEFF_W-1:0]     coeff_wr_data,
    output reg                      out_valid,
    output reg signed [DATA_W-1:0]  out_i,
    output reg signed [DATA_W-1:0]  out_q
);

    localparam S_CAPTURE = 4'd0;
    localparam S_DEC5    = 4'd1;
    localparam S_FIR2    = 4'd2;
    localparam S_FIR1    = 4'd3;
    localparam S_RHB3    = 4'd4;
    localparam S_RHB2    = 4'd5;
    localparam S_RHB1    = 4'd6;
    localparam S_PFIR    = 4'd7;
    localparam S_OUTPUT  = 4'd8;

    integer idx;

    reg [3:0] state;

    reg front_path_fir_chain_d;
    reg dec5_bypass_d;
    reg fir2_bypass_d;
    reg fir1_bypass_d;
    reg rhb2_bypass_d;
    reg rhb1_mode_lp_d;
    reg hr_bypass_d;
    reg lp_bypass_d;
    reg pfir_bypass_d;
    reg [2:0] pfir_decim_d;
    reg [1:0] pfir_gain_sel_d;
    reg [6:0] pfir_tap_count_d;
    reg [15:0] input_count_d;

    reg [15:0] capture_idx;
    reg [15:0] feed_idx;
    reg [15:0] out_idx;
    reg [15:0] expected_count;
    reg [15:0] feed_total;
    reg [15:0] output_idx;

    reg [15:0] count_front;
    reg [15:0] count_fir2;
    reg [15:0] count_fir1;
    reg [15:0] count_rhb3;
    reg [15:0] count_rhb2;
    reg [15:0] count_rhb1;
    reg [15:0] count_pfir;

    reg signed [DATA_W-1:0] input_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] input_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] front_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] front_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] fir2_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] fir2_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] fir1_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] fir1_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb3_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb3_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb2_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb2_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb1_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] rhb1_buf_q [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] pfir_buf_i [0:MAX_BUFFER_SAMPLES-1];
    reg signed [DATA_W-1:0] pfir_buf_q [0:MAX_BUFFER_SAMPLES-1];

    wire front_dec5_in_valid;
    wire signed [DATA_W-1:0] front_dec5_in_i;
    wire signed [DATA_W-1:0] front_dec5_in_q;
    wire front_dec5_out_valid;
    wire signed [DATA_W-1:0] front_dec5_out_i;
    wire signed [DATA_W-1:0] front_dec5_out_q;

    wire fir2_in_valid;
    wire signed [DATA_W-1:0] fir2_in_i;
    wire signed [DATA_W-1:0] fir2_in_q;
    wire fir2_out_valid;
    wire signed [DATA_W-1:0] fir2_out_i;
    wire signed [DATA_W-1:0] fir2_out_q;

    wire fir1_in_valid;
    wire signed [DATA_W-1:0] fir1_in_i;
    wire signed [DATA_W-1:0] fir1_in_q;
    wire fir1_out_valid;
    wire signed [DATA_W-1:0] fir1_out_i;
    wire signed [DATA_W-1:0] fir1_out_q;

    wire rhb3_in_valid;
    wire signed [DATA_W-1:0] rhb3_in_i;
    wire signed [DATA_W-1:0] rhb3_in_q;
    wire rhb3_out_valid;
    wire signed [DATA_W-1:0] rhb3_out_i;
    wire signed [DATA_W-1:0] rhb3_out_q;

    wire rhb2_in_valid;
    wire signed [DATA_W-1:0] rhb2_in_i;
    wire signed [DATA_W-1:0] rhb2_in_q;
    wire rhb2_out_valid;
    wire signed [DATA_W-1:0] rhb2_out_i;
    wire signed [DATA_W-1:0] rhb2_out_q;

    wire rhb1_hr_in_valid;
    wire signed [DATA_W-1:0] rhb1_hr_in_i;
    wire signed [DATA_W-1:0] rhb1_hr_in_q;
    wire rhb1_hr_out_valid;
    wire signed [DATA_W-1:0] rhb1_hr_out_i;
    wire signed [DATA_W-1:0] rhb1_hr_out_q;

    wire rhb1_lp_in_valid;
    wire signed [DATA_W-1:0] rhb1_lp_in_i;
    wire signed [DATA_W-1:0] rhb1_lp_in_q;
    wire rhb1_lp_out_valid;
    wire signed [DATA_W-1:0] rhb1_lp_out_i;
    wire signed [DATA_W-1:0] rhb1_lp_out_q;

    wire pfir_in_valid;
    wire signed [DATA_W-1:0] pfir_in_i;
    wire signed [DATA_W-1:0] pfir_in_q;
    wire pfir_out_valid;
    wire signed [DATA_W-1:0] pfir_out_i;
    wire signed [DATA_W-1:0] pfir_out_q;

    function [15:0] stage_output_count;
        input [15:0] in_count;
        input bypass;
        input [15:0] tap_count;
        input [2:0] decim;
        reg [15:0] numerator;
        begin
            if (bypass) begin
                stage_output_count = in_count;
            end else begin
                numerator = in_count + tap_count - 1 + decim - 1;
                stage_output_count = numerator / decim;
            end
        end
    endfunction

    function [15:0] stage_feed_total;
        input [15:0] in_count;
        input bypass;
        input [15:0] tap_count;
        begin
            if (bypass) begin
                stage_feed_total = in_count;
            end else begin
                stage_feed_total = in_count + tap_count - 1;
            end
        end
    endfunction

    assign in_ready = (state == S_CAPTURE) && (capture_idx < ((capture_idx == 16'd0) ? cfg_input_count : input_count_d));

    assign front_dec5_in_valid = (state == S_DEC5) && (feed_idx < feed_total);
    assign front_dec5_in_i = (feed_idx < input_count_d) ? input_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign front_dec5_in_q = (feed_idx < input_count_d) ? input_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign fir2_in_valid = (state == S_FIR2) && (feed_idx < feed_total);
    assign fir2_in_i = (feed_idx < input_count_d) ? input_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign fir2_in_q = (feed_idx < input_count_d) ? input_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign fir1_in_valid = (state == S_FIR1) && (feed_idx < feed_total);
    assign fir1_in_i = (feed_idx < count_fir2) ? fir2_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign fir1_in_q = (feed_idx < count_fir2) ? fir2_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign rhb3_in_valid = (state == S_RHB3) && (feed_idx < feed_total);
    assign rhb3_in_i = (feed_idx < count_fir1) ? fir1_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign rhb3_in_q = (feed_idx < count_fir1) ? fir1_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign rhb2_in_valid = (state == S_RHB2) && (feed_idx < feed_total);
    assign rhb2_in_i = (feed_idx < count_front) ? front_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign rhb2_in_q = (feed_idx < count_front) ? front_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign rhb1_hr_in_valid = (state == S_RHB1) && !rhb1_mode_lp_d && (feed_idx < feed_total);
    assign rhb1_hr_in_i = (feed_idx < count_rhb2) ? rhb2_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign rhb1_hr_in_q = (feed_idx < count_rhb2) ? rhb2_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign rhb1_lp_in_valid = (state == S_RHB1) && rhb1_mode_lp_d && (feed_idx < feed_total);
    assign rhb1_lp_in_i = (feed_idx < count_rhb2) ? rhb2_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign rhb1_lp_in_q = (feed_idx < count_rhb2) ? rhb2_buf_q[feed_idx] : {DATA_W{1'b0}};

    assign pfir_in_valid = (state == S_PFIR) && (feed_idx < feed_total);
    assign pfir_in_i = (feed_idx < count_rhb1) ? rhb1_buf_i[feed_idx] : {DATA_W{1'b0}};
    assign pfir_in_q = (feed_idx < count_rhb1) ? rhb1_buf_q[feed_idx] : {DATA_W{1'b0}};

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(5),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(33),
        .DECIM_FACTOR(5),
        .MAX_TAPS(61)
    ) u_dec5 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(front_dec5_in_valid),
        .in_ready(),
        .in_i(front_dec5_in_i),
        .in_q(front_dec5_in_q),
        .cfg_bypass(dec5_bypass_d),
        .out_valid(front_dec5_out_valid),
        .out_i(front_dec5_out_i),
        .out_q(front_dec5_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(0),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(5),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_fir2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fir2_in_valid),
        .in_ready(),
        .in_i(fir2_in_i),
        .in_q(fir2_in_q),
        .cfg_bypass(fir2_bypass_d),
        .out_valid(fir2_out_valid),
        .out_i(fir2_out_i),
        .out_q(fir2_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(0),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(5),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_fir1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fir1_in_valid),
        .in_ready(),
        .in_i(fir1_in_i),
        .in_q(fir1_in_q),
        .cfg_bypass(fir1_bypass_d),
        .out_valid(fir1_out_valid),
        .out_i(fir1_out_i),
        .out_q(fir1_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(1),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(7),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_rhb3 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rhb3_in_valid),
        .in_ready(),
        .in_i(rhb3_in_i),
        .in_q(rhb3_in_q),
        .cfg_bypass(1'b0),
        .out_valid(rhb3_out_valid),
        .out_i(rhb3_out_i),
        .out_q(rhb3_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(2),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(23),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_rhb2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rhb2_in_valid),
        .in_ready(),
        .in_i(rhb2_in_i),
        .in_q(rhb2_in_q),
        .cfg_bypass(rhb2_bypass_d),
        .out_valid(rhb2_out_valid),
        .out_i(rhb2_out_i),
        .out_q(rhb2_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(3),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(59),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_hr (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rhb1_hr_in_valid),
        .in_ready(),
        .in_i(rhb1_hr_in_i),
        .in_q(rhb1_hr_in_q),
        .cfg_bypass(hr_bypass_d),
        .out_valid(rhb1_hr_out_valid),
        .out_i(rhb1_hr_out_i),
        .out_q(rhb1_hr_out_q)
    );

    rx_fixed_decim_filter_rtl #(
        .FILTER_ID(4),
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TAP_COUNT(15),
        .DECIM_FACTOR(2),
        .MAX_TAPS(61)
    ) u_lp (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rhb1_lp_in_valid),
        .in_ready(),
        .in_i(rhb1_lp_in_i),
        .in_q(rhb1_lp_in_q),
        .cfg_bypass(lp_bypass_d),
        .out_valid(rhb1_lp_out_valid),
        .out_i(rhb1_lp_out_i),
        .out_q(rhb1_lp_out_q)
    );

    rx_pfir_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(PFIR_MAX_TAPS),
        .TAP_ADDR_W(7)
    ) u_pfir (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(pfir_in_valid),
        .in_ready(),
        .in_i(pfir_in_i),
        .in_q(pfir_in_q),
        .cfg_bypass(pfir_bypass_d),
        .cfg_decim(pfir_decim_d),
        .cfg_gain_sel(pfir_gain_sel_d),
        .cfg_tap_count(pfir_tap_count_d),
        .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data),
        .out_valid(pfir_out_valid),
        .out_i(pfir_out_i),
        .out_q(pfir_out_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_CAPTURE;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};
            front_path_fir_chain_d <= 1'b0;
            dec5_bypass_d <= 1'b0;
            fir2_bypass_d <= 1'b0;
            fir1_bypass_d <= 1'b0;
            rhb2_bypass_d <= 1'b0;
            rhb1_mode_lp_d <= 1'b0;
            hr_bypass_d <= 1'b0;
            lp_bypass_d <= 1'b0;
            pfir_bypass_d <= 1'b0;
            pfir_decim_d <= 3'd1;
            pfir_gain_sel_d <= 2'd1;
            pfir_tap_count_d <= 7'd24;
            input_count_d <= 16'd0;
            capture_idx <= 16'd0;
            feed_idx <= 16'd0;
            out_idx <= 16'd0;
            expected_count <= 16'd0;
            feed_total <= 16'd0;
            output_idx <= 16'd0;
            count_front <= 16'd0;
            count_fir2 <= 16'd0;
            count_fir1 <= 16'd0;
            count_rhb3 <= 16'd0;
            count_rhb2 <= 16'd0;
            count_rhb1 <= 16'd0;
            count_pfir <= 16'd0;
            for (idx = 0; idx < MAX_BUFFER_SAMPLES; idx = idx + 1) begin
                input_buf_i[idx] <= {DATA_W{1'b0}};
                input_buf_q[idx] <= {DATA_W{1'b0}};
                front_buf_i[idx] <= {DATA_W{1'b0}};
                front_buf_q[idx] <= {DATA_W{1'b0}};
                fir2_buf_i[idx] <= {DATA_W{1'b0}};
                fir2_buf_q[idx] <= {DATA_W{1'b0}};
                fir1_buf_i[idx] <= {DATA_W{1'b0}};
                fir1_buf_q[idx] <= {DATA_W{1'b0}};
                rhb3_buf_i[idx] <= {DATA_W{1'b0}};
                rhb3_buf_q[idx] <= {DATA_W{1'b0}};
                rhb2_buf_i[idx] <= {DATA_W{1'b0}};
                rhb2_buf_q[idx] <= {DATA_W{1'b0}};
                rhb1_buf_i[idx] <= {DATA_W{1'b0}};
                rhb1_buf_q[idx] <= {DATA_W{1'b0}};
                pfir_buf_i[idx] <= {DATA_W{1'b0}};
                pfir_buf_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;
            case (state)
                S_CAPTURE: begin
                    if (capture_idx == 16'd0) begin
                        input_count_d <= cfg_input_count;
                        front_path_fir_chain_d <= cfg_front_path_fir_chain;
                        dec5_bypass_d <= cfg_dec5_bypass;
                        fir2_bypass_d <= cfg_fir2_bypass;
                        fir1_bypass_d <= cfg_fir1_bypass;
                        rhb2_bypass_d <= cfg_rhb2_bypass;
                        rhb1_mode_lp_d <= cfg_rhb1_mode_lp;
                        hr_bypass_d <= cfg_hr_bypass;
                        lp_bypass_d <= cfg_lp_bypass;
                        pfir_bypass_d <= cfg_pfir_bypass;
                        pfir_decim_d <= cfg_pfir_decim;
                        pfir_gain_sel_d <= cfg_pfir_gain_sel;
                        pfir_tap_count_d <= cfg_pfir_tap_count;
                    end

                    if (in_valid && in_ready) begin
                        input_buf_i[capture_idx] <= in_i;
                        input_buf_q[capture_idx] <= in_q;
                        if (capture_idx == cfg_input_count - 1) begin
                            capture_idx <= 16'd0;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            if (cfg_front_path_fir_chain) begin
                                expected_count <= stage_output_count(cfg_input_count, cfg_fir2_bypass, 16'd5, 3'd2);
                                feed_total <= stage_feed_total(cfg_input_count, cfg_fir2_bypass, 16'd5);
                                state <= S_FIR2;
                            end else begin
                                expected_count <= stage_output_count(cfg_input_count, cfg_dec5_bypass, 16'd33, 3'd5);
                                feed_total <= stage_feed_total(cfg_input_count, cfg_dec5_bypass, 16'd33);
                                state <= S_DEC5;
                            end
                        end else begin
                            capture_idx <= capture_idx + 16'd1;
                        end
                    end
                end

                S_DEC5: begin
                    if (front_dec5_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (front_dec5_out_valid) begin
                        front_buf_i[out_idx] <= front_dec5_out_i;
                        front_buf_q[out_idx] <= front_dec5_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_front <= expected_count;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            expected_count <= stage_output_count(expected_count, rhb2_bypass_d, 16'd23, 3'd2);
                            feed_total <= stage_feed_total(expected_count, rhb2_bypass_d, 16'd23);
                            state <= S_RHB2;
                        end
                    end
                end

                S_FIR2: begin
                    if (fir2_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (fir2_out_valid) begin
                        fir2_buf_i[out_idx] <= fir2_out_i;
                        fir2_buf_q[out_idx] <= fir2_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_fir2 <= expected_count;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            expected_count <= stage_output_count(expected_count, fir1_bypass_d, 16'd5, 3'd2);
                            feed_total <= stage_feed_total(expected_count, fir1_bypass_d, 16'd5);
                            state <= S_FIR1;
                        end
                    end
                end

                S_FIR1: begin
                    if (fir1_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (fir1_out_valid) begin
                        fir1_buf_i[out_idx] <= fir1_out_i;
                        fir1_buf_q[out_idx] <= fir1_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_fir1 <= expected_count;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            expected_count <= stage_output_count(expected_count, 1'b0, 16'd7, 3'd2);
                            feed_total <= stage_feed_total(expected_count, 1'b0, 16'd7);
                            state <= S_RHB3;
                        end
                    end
                end

                S_RHB3: begin
                    if (rhb3_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (rhb3_out_valid) begin
                        front_buf_i[out_idx] <= rhb3_out_i;
                        front_buf_q[out_idx] <= rhb3_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_front <= expected_count;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            expected_count <= stage_output_count(expected_count, rhb2_bypass_d, 16'd23, 3'd2);
                            feed_total <= stage_feed_total(expected_count, rhb2_bypass_d, 16'd23);
                            state <= S_RHB2;
                        end
                    end
                end

                S_RHB2: begin
                    if (rhb2_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (rhb2_out_valid) begin
                        rhb2_buf_i[out_idx] <= rhb2_out_i;
                        rhb2_buf_q[out_idx] <= rhb2_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_rhb2 <= expected_count;
                            feed_idx <= 16'd0;
                            out_idx <= 16'd0;
                            if (rhb1_mode_lp_d) begin
                                expected_count <= stage_output_count(expected_count, lp_bypass_d, 16'd15, 3'd2);
                                feed_total <= stage_feed_total(expected_count, lp_bypass_d, 16'd15);
                            end else begin
                                expected_count <= stage_output_count(expected_count, hr_bypass_d, 16'd59, 3'd2);
                                feed_total <= stage_feed_total(expected_count, hr_bypass_d, 16'd59);
                            end
                            state <= S_RHB1;
                        end
                    end
                end

                S_RHB1: begin
                    if (rhb1_mode_lp_d) begin
                        if (rhb1_lp_in_valid) begin
                            feed_idx <= feed_idx + 16'd1;
                        end
                        if (rhb1_lp_out_valid) begin
                            rhb1_buf_i[out_idx] <= rhb1_lp_out_i;
                            rhb1_buf_q[out_idx] <= rhb1_lp_out_q;
                            out_idx <= out_idx + 16'd1;
                            if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                                count_rhb1 <= expected_count;
                                feed_idx <= 16'd0;
                                out_idx <= 16'd0;
                                expected_count <= stage_output_count(expected_count, pfir_bypass_d, {9'd0,pfir_tap_count_d}, (pfir_decim_d == 3'd2) ? 3'd2 : ((pfir_decim_d == 3'd4) ? 3'd4 : 3'd1));
                                feed_total <= stage_feed_total(expected_count, pfir_bypass_d, {9'd0,pfir_tap_count_d});
                                state <= S_PFIR;
                            end
                        end
                    end else begin
                        if (rhb1_hr_in_valid) begin
                            feed_idx <= feed_idx + 16'd1;
                        end
                        if (rhb1_hr_out_valid) begin
                            rhb1_buf_i[out_idx] <= rhb1_hr_out_i;
                            rhb1_buf_q[out_idx] <= rhb1_hr_out_q;
                            out_idx <= out_idx + 16'd1;
                            if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                                count_rhb1 <= expected_count;
                                feed_idx <= 16'd0;
                                out_idx <= 16'd0;
                                expected_count <= stage_output_count(expected_count, pfir_bypass_d, {9'd0,pfir_tap_count_d}, (pfir_decim_d == 3'd2) ? 3'd2 : ((pfir_decim_d == 3'd4) ? 3'd4 : 3'd1));
                                feed_total <= stage_feed_total(expected_count, pfir_bypass_d, {9'd0,pfir_tap_count_d});
                                state <= S_PFIR;
                            end
                        end
                    end
                end

                S_PFIR: begin
                    if (pfir_in_valid) begin
                        feed_idx <= feed_idx + 16'd1;
                    end
                    if (pfir_out_valid) begin
                        pfir_buf_i[out_idx] <= pfir_out_i;
                        pfir_buf_q[out_idx] <= pfir_out_q;
                        out_idx <= out_idx + 16'd1;
                        if (((feed_idx == feed_total) || (feed_idx == feed_total - 1)) && (out_idx == expected_count - 1)) begin
                            count_pfir <= expected_count;
                            output_idx <= 16'd0;
                            state <= S_OUTPUT;
                        end
                    end
                end

                S_OUTPUT: begin
                    out_valid <= 1'b1;
                    out_i <= pfir_buf_i[output_idx];
                    out_q <= pfir_buf_q[output_idx];
                    if (output_idx == count_pfir - 1) begin
                        state <= S_CAPTURE;
                        capture_idx <= 16'd0;
                    end else begin
                        output_idx <= output_idx + 16'd1;
                    end
                end

                default: state <= S_CAPTURE;
            endcase
        end
    end

endmodule