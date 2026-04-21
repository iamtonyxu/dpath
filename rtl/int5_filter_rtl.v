module int5_filter_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter MAX_TAPS = 67
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
    reg [2:0] phase_idx;
    reg [2:0] phases_left;

    reg signed [DATA_W-1:0] sample_hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_q [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] phase_buf_i [0:4];
    reg signed [DATA_W-1:0] phase_buf_q [0:4];

    reg signed [ACC_W-1:0] calc_mac_i0;
    reg signed [ACC_W-1:0] calc_mac_q0;
    reg signed [ACC_W-1:0] calc_mac_i1;
    reg signed [ACC_W-1:0] calc_mac_q1;
    reg signed [ACC_W-1:0] calc_mac_i2;
    reg signed [ACC_W-1:0] calc_mac_q2;
    reg signed [ACC_W-1:0] calc_mac_i3;
    reg signed [ACC_W-1:0] calc_mac_q3;
    reg signed [ACC_W-1:0] calc_mac_i4;
    reg signed [ACC_W-1:0] calc_mac_q4;
    reg signed [DATA_W-1:0] calc_hist_i;
    reg signed [DATA_W-1:0] calc_hist_q;

    wire signed [DATA_W-1:0] gained_i0;
    wire signed [DATA_W-1:0] gained_q0;
    wire signed [DATA_W-1:0] gained_i1;
    wire signed [DATA_W-1:0] gained_q1;
    wire signed [DATA_W-1:0] gained_i2;
    wire signed [DATA_W-1:0] gained_q2;
    wire signed [DATA_W-1:0] gained_i3;
    wire signed [DATA_W-1:0] gained_q3;
    wire signed [DATA_W-1:0] gained_i4;
    wire signed [DATA_W-1:0] gained_q4;

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

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase2_i (
        .in_data(calc_mac_i2),
        .gain_sel(2'd1),
        .out_data(gained_i2)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase2_q (
        .in_data(calc_mac_q2),
        .gain_sel(2'd1),
        .out_data(gained_q2)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase3_i (
        .in_data(calc_mac_i3),
        .gain_sel(2'd1),
        .out_data(gained_i3)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase3_q (
        .in_data(calc_mac_q3),
        .gain_sel(2'd1),
        .out_data(gained_q3)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase4_i (
        .in_data(calc_mac_i4),
        .gain_sel(2'd1),
        .out_data(gained_i4)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_phase4_q (
        .in_data(calc_mac_q4),
        .gain_sel(2'd1),
        .out_data(gained_q4)
    );

    function signed [COEFF_W-1:0] coeff_at;
        input integer tap;
        begin
            case (tap)
                0: coeff_at = 16'sd48;
                1: coeff_at = 16'sd476;
                2: coeff_at = -16'sd480;
                3: coeff_at = 16'sd512;
                4: coeff_at = -16'sd200;
                5: coeff_at = -16'sd96;
                6: coeff_at = -16'sd928;
                7: coeff_at = 16'sd844;
                8: coeff_at = -16'sd912;
                9: coeff_at = 16'sd416;
                10: coeff_at = 16'sd344;
                11: coeff_at = 16'sd1332;
                12: coeff_at = -16'sd944;
                13: coeff_at = 16'sd1188;
                14: coeff_at = -16'sd740;
                15: coeff_at = -16'sd780;
                16: coeff_at = -16'sd1572;
                17: coeff_at = 16'sd500;
                18: coeff_at = -16'sd1168;
                19: coeff_at = 16'sd1124;
                20: coeff_at = 16'sd1540;
                21: coeff_at = 16'sd1864;
                22: coeff_at = 16'sd504;
                23: coeff_at = 16'sd908;
                24: coeff_at = -16'sd1700;
                25: coeff_at = -16'sd3044;
                26: coeff_at = -16'sd3036;
                27: coeff_at = -16'sd2244;
                28: coeff_at = -16'sd612;
                29: coeff_at = 16'sd3720;
                30: coeff_at = 16'sd8496;
                31: coeff_at = 16'sd11752;
                32: coeff_at = 16'sd15212;
                33: coeff_at = 16'sd16700;
                34: coeff_at = 16'sd15212;
                35: coeff_at = 16'sd11752;
                36: coeff_at = 16'sd8496;
                37: coeff_at = 16'sd3720;
                38: coeff_at = -16'sd612;
                39: coeff_at = -16'sd2244;
                40: coeff_at = -16'sd3036;
                41: coeff_at = -16'sd3044;
                42: coeff_at = -16'sd1700;
                43: coeff_at = 16'sd908;
                44: coeff_at = 16'sd504;
                45: coeff_at = 16'sd1864;
                46: coeff_at = 16'sd1540;
                47: coeff_at = 16'sd1124;
                48: coeff_at = -16'sd1168;
                49: coeff_at = 16'sd500;
                50: coeff_at = -16'sd1572;
                51: coeff_at = -16'sd780;
                52: coeff_at = -16'sd740;
                53: coeff_at = 16'sd1188;
                54: coeff_at = -16'sd944;
                55: coeff_at = 16'sd1332;
                56: coeff_at = 16'sd344;
                57: coeff_at = 16'sd416;
                58: coeff_at = -16'sd912;
                59: coeff_at = 16'sd844;
                60: coeff_at = -16'sd928;
                61: coeff_at = -16'sd96;
                62: coeff_at = -16'sd200;
                63: coeff_at = 16'sd512;
                64: coeff_at = -16'sd480;
                65: coeff_at = 16'sd476;
                66: coeff_at = 16'sd48;
                default: coeff_at = {COEFF_W{1'b0}};
            endcase
        end
    endfunction

    always @* begin
        calc_mac_i0 = {ACC_W{1'b0}};
        calc_mac_q0 = {ACC_W{1'b0}};
        calc_mac_i1 = {ACC_W{1'b0}};
        calc_mac_q1 = {ACC_W{1'b0}};
        calc_mac_i2 = {ACC_W{1'b0}};
        calc_mac_q2 = {ACC_W{1'b0}};
        calc_mac_i3 = {ACC_W{1'b0}};
        calc_mac_q3 = {ACC_W{1'b0}};
        calc_mac_i4 = {ACC_W{1'b0}};
        calc_mac_q4 = {ACC_W{1'b0}};

        if (!cfg_bypass) begin
            sample_index = 0;
            for (coeff_idx = 0; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 5) begin
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
            for (coeff_idx = 1; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 5) begin
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

            sample_index = 0;
            for (coeff_idx = 2; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 5) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                calc_mac_i2 = calc_mac_i2 + calc_hist_i * coeff_at(coeff_idx);
                calc_mac_q2 = calc_mac_q2 + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end

            sample_index = 0;
            for (coeff_idx = 3; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 5) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                calc_mac_i3 = calc_mac_i3 + calc_hist_i * coeff_at(coeff_idx);
                calc_mac_q3 = calc_mac_q3 + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end

            sample_index = 0;
            for (coeff_idx = 4; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 5) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                calc_mac_i4 = calc_mac_i4 + calc_hist_i * coeff_at(coeff_idx);
                calc_mac_q4 = calc_mac_q4 + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            bypass_d <= 1'b0;
            phase_idx <= 3'd0;
            phases_left <= 3'd0;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};

            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                sample_hist_i[idx] <= {DATA_W{1'b0}};
                sample_hist_q[idx] <= {DATA_W{1'b0}};
            end

            for (idx = 0; idx < 5; idx = idx + 1) begin
                phase_buf_i[idx] <= {DATA_W{1'b0}};
                phase_buf_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;

            if (busy) begin
                out_valid <= 1'b1;
                out_i <= phase_buf_i[phase_idx];
                out_q <= phase_buf_q[phase_idx];

                if (phases_left == 3'd1) begin
                    busy <= 1'b0;
                    phase_idx <= 3'd0;
                    phases_left <= 3'd0;
                end else begin
                    phase_idx <= phase_idx + 3'd1;
                    phases_left <= phases_left - 3'd1;
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
                phase_idx <= 3'd0;
                phases_left <= 3'd5;
                phase_buf_i[0] <= cfg_bypass ? in_i : gained_i0;
                phase_buf_q[0] <= cfg_bypass ? in_q : gained_q0;
                phase_buf_i[1] <= cfg_bypass ? {DATA_W{1'b0}} : gained_i1;
                phase_buf_q[1] <= cfg_bypass ? {DATA_W{1'b0}} : gained_q1;
                phase_buf_i[2] <= cfg_bypass ? {DATA_W{1'b0}} : gained_i2;
                phase_buf_q[2] <= cfg_bypass ? {DATA_W{1'b0}} : gained_q2;
                phase_buf_i[3] <= cfg_bypass ? {DATA_W{1'b0}} : gained_i3;
                phase_buf_q[3] <= cfg_bypass ? {DATA_W{1'b0}} : gained_q3;
                phase_buf_i[4] <= cfg_bypass ? {DATA_W{1'b0}} : gained_i4;
                phase_buf_q[4] <= cfg_bypass ? {DATA_W{1'b0}} : gained_q4;
                busy <= 1'b1;
            end
        end
    end

endmodule