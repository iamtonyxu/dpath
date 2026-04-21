`timescale 1ns/1ps

module tb_tfir_filter_rtl;

    localparam DATA_W = 16;
    localparam COEFF_W = 16;
    localparam ACC_W = 40;
    localparam FRAC_W = 14;
    localparam MAX_TAPS = 80;
    localparam TAP_ADDR_W = 7;

    localparam GAIN_P6  = 2'd0;
    localparam GAIN_0   = 2'd1;
    localparam GAIN_M6  = 2'd2;
    localparam GAIN_M12 = 2'd3;

    reg clk;
    reg rst_n;
    reg in_valid;
    wire in_ready;
    reg signed [DATA_W-1:0] in_i;
    reg signed [DATA_W-1:0] in_q;
    reg cfg_bypass;
    reg [2:0] cfg_interp;
    reg [1:0] cfg_gain_sel;
    reg [TAP_ADDR_W-1:0] cfg_tap_count;
    reg coeff_wr_en;
    reg [TAP_ADDR_W-1:0] coeff_wr_addr;
    reg signed [COEFF_W-1:0] coeff_wr_data;
    wire out_valid;
    wire signed [DATA_W-1:0] out_i;
    wire signed [DATA_W-1:0] out_q;

    reg signed [COEFF_W-1:0] coeff_ref [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] hist_i [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] hist_q [0:MAX_TAPS-1];
    reg signed [DATA_W-1:0] exp_i [0:511];
    reg signed [DATA_W-1:0] exp_q [0:511];

    integer idx;
    integer exp_wr_ptr;
    integer exp_rd_ptr;
    integer checks;
    integer interp_factor;
    integer phase;
    integer coeff_idx;
    integer sample_idx;
    reg signed [63:0] acc_i;
    reg signed [63:0] acc_q;

    tfir_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(MAX_TAPS),
        .TAP_ADDR_W(TAP_ADDR_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_i(in_i),
        .in_q(in_q),
        .cfg_bypass(cfg_bypass),
        .cfg_interp(cfg_interp),
        .cfg_gain_sel(cfg_gain_sel),
        .cfg_tap_count(cfg_tap_count),
        .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data),
        .out_valid(out_valid),
        .out_i(out_i),
        .out_q(out_q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function integer get_interp_factor;
        input [2:0] interp_cfg;
        begin
            case (interp_cfg)
                3'd2: get_interp_factor = 2;
                3'd4: get_interp_factor = 4;
                default: get_interp_factor = 1;
            endcase
        end
    endfunction

    function signed [DATA_W-1:0] scale_and_pack;
        input signed [63:0] value;
        input [1:0] gain_sel;
        reg signed [63:0] scaled;
        reg signed [63:0] normalized;
        begin
            case (gain_sel)
                GAIN_P6:  scaled = value <<< 1;
                GAIN_0:   scaled = value;
                GAIN_M6:  scaled = value >>> 1;
                default:  scaled = value >>> 2;
            endcase

            normalized = scaled >>> FRAC_W;
            scale_and_pack = normalized[DATA_W-1:0];
        end
    endfunction

    task reset_model;
        begin
            exp_wr_ptr = 0;
            exp_rd_ptr = 0;
            checks = 0;
            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                hist_i[idx] = 0;
                hist_q[idx] = 0;
            end
        end
    endtask

    task program_coeff;
        input [TAP_ADDR_W-1:0] addr;
        input signed [COEFF_W-1:0] value;
        begin
            @(posedge clk);
            coeff_wr_en <= 1'b1;
            coeff_wr_addr <= addr;
            coeff_wr_data <= value;
            coeff_ref[addr] = value;
            @(posedge clk);
            coeff_wr_en <= 1'b0;
            coeff_wr_addr <= 0;
            coeff_wr_data <= 0;
        end
    endtask

    task load_default_coeffs;
        begin
            for (idx = 0; idx < MAX_TAPS; idx = idx + 1) begin
                coeff_ref[idx] = 0;
            end

            program_coeff(7'd0, 16'sd8192);
            program_coeff(7'd1, 16'sd4096);
            program_coeff(7'd2, -16'sd2048);
            program_coeff(7'd3, 16'sd1024);
            program_coeff(7'd4, 16'sd512);
            program_coeff(7'd5, -16'sd256);
            program_coeff(7'd6, 16'sd128);
            program_coeff(7'd7, -16'sd64);
        end
    endtask

    task reset_dut_and_reload;
        begin
            rst_n = 1'b0;
            in_valid = 1'b0;
            in_i = 0;
            in_q = 0;
            coeff_wr_en = 1'b0;
            coeff_wr_addr = 0;
            coeff_wr_data = 0;
            reset_model();

            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);

            load_default_coeffs();
        end
    endtask

    task set_cfg;
        input bypass;
        input [2:0] interp;
        input [1:0] gain_sel;
        input [TAP_ADDR_W-1:0] tap_count;
        begin
            cfg_bypass = bypass;
            cfg_interp = interp;
            cfg_gain_sel = gain_sel;
            cfg_tap_count = tap_count;
        end
    endtask

    task model_accept_sample;
        input signed [DATA_W-1:0] sample_i_in;
        input signed [DATA_W-1:0] sample_q_in;
        begin
            for (idx = MAX_TAPS-1; idx > 0; idx = idx - 1) begin
                hist_i[idx] = hist_i[idx-1];
                hist_q[idx] = hist_q[idx-1];
            end
            hist_i[0] = sample_i_in;
            hist_q[0] = sample_q_in;

            if (cfg_bypass) begin
                exp_i[exp_wr_ptr] = sample_i_in;
                exp_q[exp_wr_ptr] = sample_q_in;
                exp_wr_ptr = exp_wr_ptr + 1;
            end else begin
                interp_factor = get_interp_factor(cfg_interp);
                for (phase = 0; phase < interp_factor; phase = phase + 1) begin
                    acc_i = 0;
                    acc_q = 0;
                    sample_idx = 0;

                    for (coeff_idx = phase; coeff_idx < cfg_tap_count; coeff_idx = coeff_idx + interp_factor) begin
                        acc_i = acc_i + hist_i[sample_idx] * coeff_ref[coeff_idx];
                        acc_q = acc_q + hist_q[sample_idx] * coeff_ref[coeff_idx];
                        sample_idx = sample_idx + 1;
                    end

                    exp_i[exp_wr_ptr] = scale_and_pack(acc_i, cfg_gain_sel);
                    exp_q[exp_wr_ptr] = scale_and_pack(acc_q, cfg_gain_sel);
                    exp_wr_ptr = exp_wr_ptr + 1;
                end
            end
        end
    endtask

    task push_sample;
        input signed [DATA_W-1:0] sample_i_in;
        input signed [DATA_W-1:0] sample_q_in;
        begin
            model_accept_sample(sample_i_in, sample_q_in);
            @(negedge clk);
            while (!in_ready) begin
                @(negedge clk);
            end

            in_valid <= 1'b1;
            in_i <= sample_i_in;
            in_q <= sample_q_in;

            @(posedge clk);
            in_valid <= 1'b0;
            in_i <= 0;
            in_q <= 0;
        end
    endtask

    task wait_for_expected_outputs;
        input integer expected_count;
        integer watchdog;
        begin
            watchdog = 0;
            while ((exp_rd_ptr < expected_count) && (watchdog < 2000)) begin
                @(posedge clk);
                watchdog = watchdog + 1;
            end

            if (exp_rd_ptr != expected_count) begin
                $display("ERROR: timeout waiting for outputs. expected=%0d got=%0d", expected_count, exp_rd_ptr);
                $fatal;
            end
        end
    endtask

    always @(posedge clk) begin
        if (out_valid) begin
            if (exp_rd_ptr >= exp_wr_ptr) begin
                $display("ERROR: unexpected output sample %0d", exp_rd_ptr);
                $fatal;
            end

            if ((out_i !== exp_i[exp_rd_ptr]) || (out_q !== exp_q[exp_rd_ptr])) begin
                $display("ERROR: sample %0d mismatch: got (%0d,%0d) expect (%0d,%0d)",
                         exp_rd_ptr, out_i, out_q, exp_i[exp_rd_ptr], exp_q[exp_rd_ptr]);
                $fatal;
            end

            checks = checks + 1;
            exp_rd_ptr = exp_rd_ptr + 1;
        end
    end

    initial begin
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_i = 0;
        in_q = 0;
        cfg_bypass = 1'b0;
        cfg_interp = 3'd1;
        cfg_gain_sel = GAIN_0;
        cfg_tap_count = 7'd20;
        coeff_wr_en = 1'b0;
        coeff_wr_addr = 0;
        coeff_wr_data = 0;

        reset_dut_and_reload();

        set_cfg(1'b1, 3'd4, GAIN_P6, 7'd20);
        push_sample(16'sd1200, -16'sd800);
        push_sample(-16'sd600, 16'sd300);
        push_sample(16'sd150, 16'sd75);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: bypass case passed with %0d checks", checks);

        reset_dut_and_reload();
        set_cfg(1'b0, 3'd1, GAIN_0, 7'd20);
        push_sample(16'sd4096, -16'sd2048);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: interp x1 case passed with %0d checks", checks);

        reset_dut_and_reload();
        set_cfg(1'b0, 3'd2, GAIN_M6, 7'd20);
        push_sample(16'sd1024, 16'sd512);
        push_sample(-16'sd512, 16'sd256);
        push_sample(16'sd256, -16'sd128);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: interp x2 case passed with %0d checks", checks);

        reset_dut_and_reload();
        set_cfg(1'b0, 3'd4, GAIN_P6, 7'd20);
        push_sample(16'sd900, -16'sd450);
        push_sample(-16'sd300, 16'sd150);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: interp x4 case passed with %0d checks", checks);

        $display("INFO: all TFIR RTL tests passed");
        $finish;
    end

endmodule