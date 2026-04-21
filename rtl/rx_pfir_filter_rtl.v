module rx_pfir_filter_rtl #(
    parameter DATA_W = 16,
    parameter COEFF_W = 16,
    parameter ACC_W = 40,
    parameter FRAC_W = 14,
    parameter MAX_TAPS = 72,
    parameter TAP_ADDR_W = 7
)(
    input                           clk,
    input                           rst_n,
    input                           in_valid,
    output                          in_ready,
    input  signed [DATA_W-1:0]      in_i,
    input  signed [DATA_W-1:0]      in_q,
    input                           cfg_bypass,
    input         [2:0]             cfg_decim,
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
    integer coeff_idx;
    integer sample_index;
    integer decim_factor;

    reg [2:0] decim_phase;
    reg signed [COEFF_W-1:0] coeff_mem [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] sample_hist_q [0:MAX_TAPS-1];
    reg signed [ACC_W-1:0] mac_i;
    reg signed [ACC_W-1:0] mac_q;
    reg signed [DATA_W-1:0] calc_hist_i;
    reg signed [DATA_W-1:0] calc_hist_q;

    wire signed [DATA_W-1:0] gained_i;
    wire signed [DATA_W-1:0] gained_q;

    assign in_ready = rst_n;

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_i (
        .in_data(mac_i),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_i)
    );

    tfir_gain_scale #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_gain_q (
        .in_data(mac_q),
        .gain_sel(cfg_gain_sel),
        .out_data(gained_q)
    );

    always @* begin
        case (cfg_decim)
            3'd2: decim_factor = 2;
            3'd4: decim_factor = 4;
            default: decim_factor = 1;
        endcase

        mac_i = {ACC_W{1'b0}};
        mac_q = {ACC_W{1'b0}};
        if (!cfg_bypass) begin
            sample_index = 0;
            for (coeff_idx = 0; coeff_idx < cfg_tap_count; coeff_idx = coeff_idx + 1) begin
                if (sample_index == 0) begin
                    calc_hist_i = in_i;
                    calc_hist_q = in_q;
                end else begin
                    calc_hist_i = sample_hist_i[sample_index-1];
                    calc_hist_q = sample_hist_q[sample_index-1];
                end
                mac_i = mac_i + calc_hist_i * coeff_mem[coeff_idx];
                mac_q = mac_q + calc_hist_q * coeff_mem[coeff_idx];
                sample_index = sample_index + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_phase <= 3'd7;
            out_valid <= 1'b0;
            out_i <= {DATA_W{1'b0}};
            out_q <= {DATA_W{1'b0}};
            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                coeff_mem[idx] <= {COEFF_W{1'b0}};
                sample_hist_i[idx] <= {DATA_W{1'b0}};
                sample_hist_q[idx] <= {DATA_W{1'b0}};
            end
        end else begin
            out_valid <= 1'b0;

            if (coeff_wr_en && (coeff_wr_addr < MAX_TAPS)) begin
                coeff_mem[coeff_wr_addr] <= coeff_wr_data;
            end

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
                end else if (decim_phase >= decim_factor-1) begin
                    out_valid <= 1'b1;
                    out_i <= gained_i;
                    out_q <= gained_q;
                    decim_phase <= 3'd0;
                end else begin
                    decim_phase <= decim_phase + 3'd1;
                end
            end
        end
    end

endmodule