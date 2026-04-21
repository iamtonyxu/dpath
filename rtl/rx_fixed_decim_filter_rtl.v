module rx_fixed_decim_filter_rtl #(
    parameter FILTER_ID = 0,
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter TAP_COUNT = 5,
    parameter DECIM_FACTOR = 2,
    parameter MAX_TAPS = 61
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

    reg [2:0] decim_phase;
    reg signed [DATA_W-1:0] sample_hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_q [0:MAX_TAPS-1];
    reg signed [ACC_W-1:0] mac_i;
    reg signed [ACC_W-1:0] mac_q;
    reg signed [DATA_W-1:0] calc_hist_i;
    reg signed [DATA_W-1:0] calc_hist_q;

    wire signed [DATA_W-1:0] scaled_i;
    wire signed [DATA_W-1:0] scaled_q;

    assign in_ready = rst_n;

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_scale_i (
        .in_data(mac_i),
        .gain_sel(2'd1),
        .out_data(scaled_i)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_scale_q (
        .in_data(mac_q),
        .gain_sel(2'd1),
        .out_data(scaled_q)
    );

    function signed [COEFF_W-1:0] coeff_at;
        input integer tap;
        begin
            case (FILTER_ID)
                0: begin
                    case (tap)
                        0: coeff_at = 16'sd1024;
                        1: coeff_at = 16'sd4096;
                        2: coeff_at = 16'sd6144;
                        3: coeff_at = 16'sd4096;
                        4: coeff_at = 16'sd1024;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
                1: begin
                    case (tap)
                        0: coeff_at = -16'sd544;
                        1: coeff_at = 16'sd0;
                        2: coeff_at = 16'sd4608;
                        3: coeff_at = 16'sd8128;
                        4: coeff_at = 16'sd4608;
                        5: coeff_at = 16'sd0;
                        6: coeff_at = -16'sd544;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
                2: begin
                    case (tap)
                        0: coeff_at = -16'sd4;
                        1: coeff_at = 16'sd0;
                        2: coeff_at = 16'sd28;
                        3: coeff_at = 16'sd0;
                        4: coeff_at = -16'sd128;
                        5: coeff_at = 16'sd0;
                        6: coeff_at = 16'sd440;
                        7: coeff_at = 16'sd0;
                        8: coeff_at = -16'sd1284;
                        9: coeff_at = 16'sd0;
                        10: coeff_at = 16'sd5056;
                        11: coeff_at = 16'sd8212;
                        12: coeff_at = 16'sd5056;
                        13: coeff_at = 16'sd0;
                        14: coeff_at = -16'sd1284;
                        15: coeff_at = 16'sd0;
                        16: coeff_at = 16'sd440;
                        17: coeff_at = 16'sd0;
                        18: coeff_at = -16'sd128;
                        19: coeff_at = 16'sd0;
                        20: coeff_at = 16'sd28;
                        21: coeff_at = 16'sd0;
                        22: coeff_at = -16'sd4;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
                3: begin
                    case (tap)
                        0: coeff_at = 16'sd2;
                        1: coeff_at = 16'sd0;
                        2: coeff_at = -16'sd5;
                        3: coeff_at = 16'sd0;
                        4: coeff_at = 16'sd10;
                        5: coeff_at = 16'sd0;
                        6: coeff_at = -16'sd20;
                        7: coeff_at = 16'sd0;
                        8: coeff_at = 16'sd35;
                        9: coeff_at = 16'sd0;
                        10: coeff_at = -16'sd57;
                        11: coeff_at = 16'sd0;
                        12: coeff_at = 16'sd90;
                        13: coeff_at = 16'sd0;
                        14: coeff_at = -16'sd136;
                        15: coeff_at = 16'sd0;
                        16: coeff_at = 16'sd200;
                        17: coeff_at = 16'sd0;
                        18: coeff_at = -16'sd289;
                        19: coeff_at = 16'sd0;
                        20: coeff_at = 16'sd417;
                        21: coeff_at = 16'sd0;
                        22: coeff_at = -16'sd609;
                        23: coeff_at = 16'sd0;
                        24: coeff_at = 16'sd938;
                        25: coeff_at = 16'sd0;
                        26: coeff_at = -16'sd1665;
                        27: coeff_at = 16'sd0;
                        28: coeff_at = 16'sd5153;
                        29: coeff_at = 16'sd8126;
                        30: coeff_at = 16'sd5153;
                        31: coeff_at = 16'sd0;
                        32: coeff_at = -16'sd1665;
                        33: coeff_at = 16'sd0;
                        34: coeff_at = 16'sd938;
                        35: coeff_at = 16'sd0;
                        36: coeff_at = -16'sd609;
                        37: coeff_at = 16'sd0;
                        38: coeff_at = 16'sd417;
                        39: coeff_at = 16'sd0;
                        40: coeff_at = -16'sd289;
                        41: coeff_at = 16'sd0;
                        42: coeff_at = 16'sd200;
                        43: coeff_at = 16'sd0;
                        44: coeff_at = -16'sd136;
                        45: coeff_at = 16'sd0;
                        46: coeff_at = 16'sd90;
                        47: coeff_at = 16'sd0;
                        48: coeff_at = -16'sd57;
                        49: coeff_at = 16'sd0;
                        50: coeff_at = 16'sd35;
                        51: coeff_at = 16'sd0;
                        52: coeff_at = -16'sd20;
                        53: coeff_at = 16'sd0;
                        54: coeff_at = 16'sd10;
                        55: coeff_at = 16'sd0;
                        56: coeff_at = -16'sd5;
                        57: coeff_at = 16'sd0;
                        58: coeff_at = 16'sd2;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
                4: begin
                    case (tap)
                        0: coeff_at = -16'sd44;
                        1: coeff_at = 16'sd0;
                        2: coeff_at = 16'sd284;
                        3: coeff_at = 16'sd0;
                        4: coeff_at = -16'sd1120;
                        5: coeff_at = 16'sd0;
                        6: coeff_at = 16'sd4988;
                        7: coeff_at = 16'sd8220;
                        8: coeff_at = 16'sd4988;
                        9: coeff_at = 16'sd0;
                        10: coeff_at = -16'sd1120;
                        11: coeff_at = 16'sd0;
                        12: coeff_at = 16'sd284;
                        13: coeff_at = 16'sd0;
                        14: coeff_at = -16'sd44;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
                default: begin
                    case (tap)
                        0: coeff_at = 16'sd16;
                        1: coeff_at = 16'sd20;
                        2: coeff_at = 16'sd32;
                        3: coeff_at = 16'sd32;
                        4: coeff_at = -16'sd64;
                        5: coeff_at = -16'sd128;
                        6: coeff_at = -16'sd240;
                        7: coeff_at = -16'sd308;
                        8: coeff_at = -16'sd312;
                        9: coeff_at = -16'sd124;
                        10: coeff_at = 16'sd176;
                        11: coeff_at = 16'sd684;
                        12: coeff_at = 16'sd1296;
                        13: coeff_at = 16'sd1920;
                        14: coeff_at = 16'sd2408;
                        15: coeff_at = 16'sd2712;
                        16: coeff_at = 16'sd2712;
                        17: coeff_at = 16'sd2408;
                        18: coeff_at = 16'sd1920;
                        19: coeff_at = 16'sd1296;
                        20: coeff_at = 16'sd684;
                        21: coeff_at = 16'sd176;
                        22: coeff_at = -16'sd124;
                        23: coeff_at = -16'sd312;
                        24: coeff_at = -16'sd308;
                        25: coeff_at = -16'sd240;
                        26: coeff_at = -16'sd128;
                        27: coeff_at = -16'sd64;
                        28: coeff_at = 16'sd20;
                        29: coeff_at = 16'sd32;
                        30: coeff_at = 16'sd32;
                        31: coeff_at = 16'sd20;
                        32: coeff_at = 16'sd16;
                        default: coeff_at = {COEFF_W{1'b0}};
                    endcase
                end
            endcase
        end
    endfunction

    always @* begin
        mac_i = {ACC_W{1'b0}};
        mac_q = {ACC_W{1'b0}};
        if (!cfg_bypass) begin
            sample_index = 0;
            for (coeff_idx = 0; coeff_idx < TAP_COUNT; coeff_idx = coeff_idx + 1) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                mac_i = mac_i + calc_hist_i * coeff_at(coeff_idx);
                mac_q = mac_q + calc_hist_q * coeff_at(coeff_idx);
                sample_index = sample_index + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_phase <= DECIM_FACTOR-1;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};
            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                sample_hist_i[idx] <= {DATA_W{1'b0}};
                sample_hist_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;
            if (in_valid) begin
                for (idx = MAX_TAPS-1; idx > 0; idx = idx - 1) begin
                    sample_hist_i[idx] <= sample_hist_i[idx-1];
                    sample_hist_q[idx] <= sample_hist_q[idx-1];
                end
                sample_hist_i[0] <= in_i;
                sample_hist_q[0] <= in_q;

                if (cfg_bypass) begin
                    out_valid <= 1'b1;
                    out_i <= in_i;
                    out_q <= in_q;
                    decim_phase <= 3'd0;
                end else if (decim_phase >= DECIM_FACTOR-1) begin
                    out_valid <= 1'b1;
                    out_i <= scaled_i;
                    out_q <= scaled_q;
                    decim_phase <= 3'd0;
                end else begin
                    decim_phase <= decim_phase + 3'd1;
                end
            end
        end
    end

endmodule