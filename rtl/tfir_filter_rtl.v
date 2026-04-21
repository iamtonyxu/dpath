module tfir_filter_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter MAX_TAPS = 80,
    parameter TAP_ADDR_W = 7
)(
    input                           clk,
    input                           rst_n,
    input                           in_valid,
    output                          in_ready,
    input  signed [DATA_W-1:0]      in_i,
    input  signed [DATA_W-1:0]      in_q,
    input                           cfg_bypass,
    input         [2:0]             cfg_interp,
    input         [1:0]             cfg_gain_sel,
    input         [TAP_ADDR_W-1:0]  cfg_tap_count,
    input                           coeff_wr_en,
    input         [TAP_ADDR_W-1:0]  coeff_wr_addr,
    input  signed [COEFF_W-1:0]     coeff_wr_data,
    output reg                      out_valid,
    output reg signed [DATA_W-1:0]  out_i,
    output reg signed [DATA_W-1:0]  out_q
);

    integer idx;
    integer sample_index;
    integer interp_factor_cfg;
    integer coeff_idx;

    reg busy;
    reg bypass_d;
    reg [2:0] phase_idx;
    reg [2:0] phases_left;

    reg signed [COEFF_W-1:0] coeff_mem [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_q [0:MAX_TAPS-1];

    reg signed [DATA_W-1:0] phase_buf_i [0:3];
    reg signed [DATA_W-1:0] phase_buf_q [0:3];

    reg signed [ACC_W-1:0] calc_mac_i0;
    reg signed [ACC_W-1:0] calc_mac_q0;
    reg signed [ACC_W-1:0] calc_mac_i1;
    reg signed [ACC_W-1:0] calc_mac_q1;
    reg signed [ACC_W-1:0] calc_mac_i2;
    reg signed [ACC_W-1:0] calc_mac_q2;
    reg signed [ACC_W-1:0] calc_mac_i3;
    reg signed [ACC_W-1:0] calc_mac_q3;

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

    assign in_ready = rst_n && !busy;

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_i0 (
        .in_data(calc_mac_i0),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_i0)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_q0 (
        .in_data(calc_mac_q0),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_q0)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_i1 (
        .in_data(calc_mac_i1),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_i1)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_q1 (
        .in_data(calc_mac_q1),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_q1)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_i2 (
        .in_data(calc_mac_i2),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_i2)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_q2 (
        .in_data(calc_mac_q2),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_q2)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_i3 (
        .in_data(calc_mac_i3),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_i3)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_q3 (
        .in_data(calc_mac_q3),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_q3)
    );

    always @* begin
        case (cfg_interp)
            3'd2: interp_factor_cfg = 2;
            3'd4: interp_factor_cfg = 4;
            default: interp_factor_cfg = 1;
        endcase

        calc_mac_i0 = {ACC_W{1'b0}};
        calc_mac_q0 = {ACC_W{1'b0}};
        calc_mac_i1 = {ACC_W{1'b0}};
        calc_mac_q1 = {ACC_W{1'b0}};
        calc_mac_i2 = {ACC_W{1'b0}};
        calc_mac_q2 = {ACC_W{1'b0}};
        calc_mac_i3 = {ACC_W{1'b0}};
        calc_mac_q3 = {ACC_W{1'b0}};

        if (!cfg_bypass) begin
            for (coeff_idx = 0; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 1) begin
                if (coeff_idx < cfg_tap_count) begin
                    case (interp_factor_cfg)
                        2: begin
                            sample_index = coeff_idx / 2;
                            if (sample_index == 0) begin
                                calc_hist_i = in_i;
                                calc_hist_q = in_q;
                            end else begin
                                calc_hist_i = sample_hist_i[sample_index-1];
                                calc_hist_q = sample_hist_q[sample_index-1];
                            end

                            if (coeff_idx[0] == 1'b0) begin
                                calc_mac_i0 = calc_mac_i0 + calc_hist_i * coeff_mem[coeff_idx];
                                calc_mac_q0 = calc_mac_q0 + calc_hist_q * coeff_mem[coeff_idx];
                            end else begin
                                calc_mac_i1 = calc_mac_i1 + calc_hist_i * coeff_mem[coeff_idx];
                                calc_mac_q1 = calc_mac_q1 + calc_hist_q * coeff_mem[coeff_idx];
                            end
                        end

                        4: begin
                            sample_index = coeff_idx / 4;
                            if (sample_index == 0) begin
                                calc_hist_i = in_i;
                                calc_hist_q = in_q;
                            end else begin
                                calc_hist_i = sample_hist_i[sample_index-1];
                                calc_hist_q = sample_hist_q[sample_index-1];
                            end

                            case (coeff_idx[1:0])
                                2'd0: begin
                                    calc_mac_i0 = calc_mac_i0 + calc_hist_i * coeff_mem[coeff_idx];
                                    calc_mac_q0 = calc_mac_q0 + calc_hist_q * coeff_mem[coeff_idx];
                                end
                                2'd1: begin
                                    calc_mac_i1 = calc_mac_i1 + calc_hist_i * coeff_mem[coeff_idx];
                                    calc_mac_q1 = calc_mac_q1 + calc_hist_q * coeff_mem[coeff_idx];
                                end
                                2'd2: begin
                                    calc_mac_i2 = calc_mac_i2 + calc_hist_i * coeff_mem[coeff_idx];
                                    calc_mac_q2 = calc_mac_q2 + calc_hist_q * coeff_mem[coeff_idx];
                                end
                                default: begin
                                    calc_mac_i3 = calc_mac_i3 + calc_hist_i * coeff_mem[coeff_idx];
                                    calc_mac_q3 = calc_mac_q3 + calc_hist_q * coeff_mem[coeff_idx];
                                end
                            endcase
                        end

                        default: begin
                            sample_index = coeff_idx;
                            if (sample_index == 0) begin
                                calc_hist_i = in_i;
                                calc_hist_q = in_q;
                            end else begin
                                calc_hist_i = sample_hist_i[sample_index-1];
                                calc_hist_q = sample_hist_q[sample_index-1];
                            end

                            calc_mac_i0 = calc_mac_i0 + calc_hist_i * coeff_mem[coeff_idx];
                            calc_mac_q0 = calc_mac_q0 + calc_hist_q * coeff_mem[coeff_idx];
                        end
                    endcase
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            bypass_d   <= 1'b0;
            phase_idx  <= 3'd0;
            phases_left <= 3'd0;
            out_valid  <= 1'b0;
            out_i      <= {DATA_W{1'b0}};
            out_q      <= {DATA_W{1'b0}};

            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                coeff_mem[idx] <= {COEFF_W{1'b0}};
                sample_hist_i[idx] <= {DATA_W{1'b0}};
                sample_hist_q[idx] <= {DATA_W{1'b0}};
            end

            for (idx = 0; idx < 4; idx = idx + 1) begin
                phase_buf_i[idx] <= {DATA_W{1'b0}};
                phase_buf_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;

            if (coeff_wr_en && (coeff_wr_addr < MAX_TAPS)) begin
                coeff_mem[coeff_wr_addr] <= coeff_wr_data;
            end

            if (busy) begin
                if (bypass_d) begin
                    out_valid <= 1'b1;
                    out_i <= phase_buf_i[0];
                    out_q <= phase_buf_q[0];
                    busy <= 1'b0;
                end else begin
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
                phase_buf_i[0] <= cfg_bypass ? in_i : gained_i0;
                phase_buf_q[0] <= cfg_bypass ? in_q : gained_q0;
                phase_buf_i[1] <= gained_i1;
                phase_buf_q[1] <= gained_q1;
                phase_buf_i[2] <= gained_i2;
                phase_buf_q[2] <= gained_q2;
                phase_buf_i[3] <= gained_i3;
                phase_buf_q[3] <= gained_q3;

                if (cfg_bypass) begin
                    phases_left <= 3'd1;
                    busy <= 1'b1;
                end else begin
                    case (cfg_interp)
                        3'd2: phases_left <= 3'd2;
                        3'd4: phases_left <= 3'd4;
                        default: phases_left <= 3'd1;
                    endcase
                    busy <= 1'b1;
                end
            end
        end
    end

endmodule