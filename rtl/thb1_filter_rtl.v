module thb1_filter_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter MAX_TAPS = 71
)(
    input                          clk,
    input                          rst_n,
    input                          in_valid,
    output                         in_ready,
    input  signed [DATA_W-1:0]     in_i,
    input  signed [DATA_W-1:0]     in_q,
    input                          cfg_bypass,
    output reg                     out_valid,
    output reg signed [DATA_W-1:0] out_i,
    output reg signed [DATA_W-1:0] out_q
);

    integer idx;
    integer coeff_idx;
    integer sample_index;

    reg busy;
    reg bypass_d;
    reg phase_sel;

    reg signed [DATA_W-1:0] sample_hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_q [0:MAX_TAPS-1];

    reg signed [DATA_W-1:0] phase_buf_i [0:1];
    reg signed [DATA_W-1:0] phase_buf_q [0:1];

    reg signed [ACC_W-1:0] calc_mac_i0;
    reg signed [ACC_W-1:0] calc_mac_q0;
    reg signed [ACC_W-1:0] calc_mac_i1;
    reg signed [ACC_W-1:0] calc_mac_q1;
    reg signed [DATA_W-1:0] calc_hist_i;
    reg signed [DATA_W-1:0] calc_hist_q;

    wire signed [DATA_W-1:0] gained_i0;
    wire signed [DATA_W-1:0] gained_q0;
    wire signed [DATA_W-1:0] gained_i1;
    wire signed [DATA_W-1:0] gained_q1;

    assign in_ready = rst_n && !busy;

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase0_i (
        .in_data(calc_mac_i0),
        .gain_sel(2'd1),
        .out_data(gained_i0)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase0_q (
        .in_data(calc_mac_q0),
        .gain_sel(2'd1),
        .out_data(gained_q0)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase1_i (
        .in_data(calc_mac_i1),
        .gain_sel(2'd1),
        .out_data(gained_i1)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase1_q (
        .in_data(calc_mac_q1),
        .gain_sel(2'd1),
        .out_data(gained_q1)
    );

    function signed [COEFF_W-1:0] coeff_at;
        input integer tap;
        begin
            case (tap)
                0:  coeff_at = -16'sd38;
                1:  coeff_at = 16'sd0;
                2:  coeff_at = 16'sd59;
                3:  coeff_at = 16'sd0;
                4:  coeff_at = -16'sd67;
                5:  coeff_at = 16'sd0;
                6:  coeff_at = 16'sd67;
                7:  coeff_at = 16'sd0;
                8:  coeff_at = -16'sd106;
                9:  coeff_at = 16'sd0;
                10: coeff_at = 16'sd157;
                11: coeff_at = 16'sd0;
                12: coeff_at = -16'sd197;
                13: coeff_at = 16'sd0;
                14: coeff_at = 16'sd236;
                15: coeff_at = 16'sd0;
                16: coeff_at = -16'sd307;
                17: coeff_at = 16'sd0;
                18: coeff_at = 16'sd398;
                19: coeff_at = 16'sd0;
                20: coeff_at = -16'sd492;
                21: coeff_at = 16'sd0;
                22: coeff_at = 16'sd612;
                23: coeff_at = 16'sd0;
                24: coeff_at = -16'sd789;
                25: coeff_at = 16'sd0;
                26: coeff_at = 16'sd1031;
                27: coeff_at = 16'sd0;
                28: coeff_at = -16'sd1382;
                29: coeff_at = 16'sd0;
                30: coeff_at = 16'sd2004;
                31: coeff_at = 16'sd0;
                32: coeff_at = -16'sd3434;
                33: coeff_at = 16'sd0;
                34: coeff_at = 16'sd10419;
                35: coeff_at = 16'sd16384;
                36: coeff_at = 16'sd10419;
                37: coeff_at = 16'sd0;
                38: coeff_at = -16'sd3434;
                39: coeff_at = 16'sd0;
                40: coeff_at = 16'sd2004;
                41: coeff_at = 16'sd0;
                42: coeff_at = -16'sd1382;
                43: coeff_at = 16'sd0;
                44: coeff_at = 16'sd1031;
                45: coeff_at = 16'sd0;
                46: coeff_at = -16'sd789;
                47: coeff_at = 16'sd0;
                48: coeff_at = 16'sd612;
                49: coeff_at = 16'sd0;
                50: coeff_at = -16'sd492;
                51: coeff_at = 16'sd0;
                52: coeff_at = 16'sd398;
                53: coeff_at = 16'sd0;
                54: coeff_at = -16'sd307;
                55: coeff_at = 16'sd0;
                56: coeff_at = 16'sd236;
                57: coeff_at = 16'sd0;
                58: coeff_at = -16'sd197;
                59: coeff_at = 16'sd0;
                60: coeff_at = 16'sd157;
                61: coeff_at = 16'sd0;
                62: coeff_at = -16'sd106;
                63: coeff_at = 16'sd0;
                64: coeff_at = 16'sd67;
                65: coeff_at = 16'sd0;
                66: coeff_at = -16'sd67;
                67: coeff_at = 16'sd0;
                68: coeff_at = 16'sd59;
                69: coeff_at = 16'sd0;
                70: coeff_at = -16'sd38;
                default: coeff_at = {COEFF_W{1'b0}};
            endcase
        end
    endfunction

    always @* begin
        calc_mac_i0 = {ACC_W{1'b0}};
        calc_mac_q0 = {ACC_W{1'b0}};
        calc_mac_i1 = {ACC_W{1'b0}};
        calc_mac_q1 = {ACC_W{1'b0}};

        if (!cfg_bypass) begin
            sample_index = 0;
            for (coeff_idx = 0; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 2) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                calc_mac_i0 = calc_mac_i0 + calc_hist_i * coeff_at(coeff_idx);
                calc_mac_q0 = calc_mac_q0 + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end

            sample_index = 0;
            for (coeff_idx = 1; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 2) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                calc_mac_i1 = calc_mac_i1 + calc_hist_i * coeff_at(coeff_idx);
                calc_mac_q1 = calc_mac_q1 + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            bypass_d <= 1'b0;
            phase_sel <= 1'b0;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};

            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                sample_hist_i[idx] <= {DATA_W{1'b0}};
                sample_hist_q[idx] <= {DATA_W{1'b0}};
            end

            phase_buf_i[0] <= {DATA_W{1'b0}};
            phase_buf_i[1] <= {DATA_W{1'b0}};
            phase_buf_q[0] <= {DATA_W{1'b0}};
            phase_buf_q[1] <= {DATA_W{1'b0}};
        end else begin
            out_valid <= 1'b0;

            if (busy) begin
                out_valid <= 1'b1;
                out_i <= phase_buf_i[phase_sel];
                out_q <= phase_buf_q[phase_sel];

                if (bypass_d || phase_sel) begin
                    busy <= 1'b0;
                    phase_sel <= 1'b0;
                end else begin
                    phase_sel <= 1'b1;
                end
            end

            if (in_valid && in_ready) begin
                for (idx = MAX_TAPS-1; idx > 0; idx = idx - 1) begin
                    sample_hist_i[idx] <= sample_hist_i[idx-1];
                    sample_hist_q[idx] <= sample_hist_q[idx-1];
                end
                sample_hist_i[0] <= in_i;
                sample_hist_q[0] <= in_q;

                bypass_d <= cfg_bypass;
                phase_sel <= 1'b0;
                phase_buf_i[0] <= cfg_bypass ? in_i : gained_i0;
                phase_buf_q[0] <= cfg_bypass ? in_q : gained_q0;
                phase_buf_i[1] <= gained_i1;
                phase_buf_q[1] <= gained_q1;
                busy <= 1'b1;
            end
        end
    end

endmodule