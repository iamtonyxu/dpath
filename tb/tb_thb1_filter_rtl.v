`timescale 1ns/1ps

module tb_thb1_filter_rtl;

    localparam DATA_W = 16;
    localparam COEFF_W = 16;
    localparam ACC_W = 40;
    localparam FRAC_W = 14;
    localparam MAX_TAPS = 71;

    reg clk;
    reg rst_n;
    reg in_valid;
    wire in_ready;
    reg signed [DATA_W-1:0] in_i;
    reg signed [DATA_W-1:0] in_q;
    reg cfg_bypass;
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
    integer coeff_idx;
    integer sample_index;
    reg signed [63:0] acc_i;
    reg signed [63:0] acc_q;

    thb1_filter_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .MAX_TAPS(MAX_TAPS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_i(in_i),
        .in_q(in_q),
        .cfg_bypass(cfg_bypass),
        .out_valid(out_valid),
        .out_i(out_i),
        .out_q(out_q)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function signed [DATA_W-1:0] normalize_mac;
        input signed [63:0] value;
        reg signed [63:0] normalized;
        begin
            normalized = value >>> FRAC_W;
            normalize_mac = normalized[DATA_W-1:0];
        end
    endfunction

    task load_coeffs;
        begin
            coeff_ref[0]  = -16'sd38;
            coeff_ref[1]  = 16'sd0;
            coeff_ref[2]  = 16'sd59;
            coeff_ref[3]  = 16'sd0;
            coeff_ref[4]  = -16'sd67;
            coeff_ref[5]  = 16'sd0;
            coeff_ref[6]  = 16'sd67;
            coeff_ref[7]  = 16'sd0;
            coeff_ref[8]  = -16'sd106;
            coeff_ref[9]  = 16'sd0;
            coeff_ref[10] = 16'sd157;
            coeff_ref[11] = 16'sd0;
            coeff_ref[12] = -16'sd197;
            coeff_ref[13] = 16'sd0;
            coeff_ref[14] = 16'sd236;
            coeff_ref[15] = 16'sd0;
            coeff_ref[16] = -16'sd307;
            coeff_ref[17] = 16'sd0;
            coeff_ref[18] = 16'sd398;
            coeff_ref[19] = 16'sd0;
            coeff_ref[20] = -16'sd492;
            coeff_ref[21] = 16'sd0;
            coeff_ref[22] = 16'sd612;
            coeff_ref[23] = 16'sd0;
            coeff_ref[24] = -16'sd789;
            coeff_ref[25] = 16'sd0;
            coeff_ref[26] = 16'sd1031;
            coeff_ref[27] = 16'sd0;
            coeff_ref[28] = -16'sd1382;
            coeff_ref[29] = 16'sd0;
            coeff_ref[30] = 16'sd2004;
            coeff_ref[31] = 16'sd0;
            coeff_ref[32] = -16'sd3434;
            coeff_ref[33] = 16'sd0;
            coeff_ref[34] = 16'sd10419;
            coeff_ref[35] = 16'sd16384;
            coeff_ref[36] = 16'sd10419;
            coeff_ref[37] = 16'sd0;
            coeff_ref[38] = -16'sd3434;
            coeff_ref[39] = 16'sd0;
            coeff_ref[40] = 16'sd2004;
            coeff_ref[41] = 16'sd0;
            coeff_ref[42] = -16'sd1382;
            coeff_ref[43] = 16'sd0;
            coeff_ref[44] = 16'sd1031;
            coeff_ref[45] = 16'sd0;
            coeff_ref[46] = -16'sd789;
            coeff_ref[47] = 16'sd0;
            coeff_ref[48] = 16'sd612;
            coeff_ref[49] = 16'sd0;
            coeff_ref[50] = -16'sd492;
            coeff_ref[51] = 16'sd0;
            coeff_ref[52] = 16'sd398;
            coeff_ref[53] = 16'sd0;
            coeff_ref[54] = -16'sd307;
            coeff_ref[55] = 16'sd0;
            coeff_ref[56] = 16'sd236;
            coeff_ref[57] = 16'sd0;
            coeff_ref[58] = -16'sd197;
            coeff_ref[59] = 16'sd0;
            coeff_ref[60] = 16'sd157;
            coeff_ref[61] = 16'sd0;
            coeff_ref[62] = -16'sd106;
            coeff_ref[63] = 16'sd0;
            coeff_ref[64] = 16'sd67;
            coeff_ref[65] = 16'sd0;
            coeff_ref[66] = -16'sd67;
            coeff_ref[67] = 16'sd0;
            coeff_ref[68] = 16'sd59;
            coeff_ref[69] = 16'sd0;
            coeff_ref[70] = -16'sd38;
        end
    endtask

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

    task reset_dut;
        begin
            rst_n = 1'b0;
            in_valid = 1'b0;
            in_i = 0;
            in_q = 0;
            cfg_bypass = 1'b0;
            reset_model();
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
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
                acc_i = 0;
                acc_q = 0;
                sample_index = 0;
                for (coeff_idx = 0; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 2) begin
                    acc_i = acc_i + hist_i[sample_index] * coeff_ref[coeff_idx];
                    acc_q = acc_q + hist_q[sample_index] * coeff_ref[coeff_idx];
                    sample_index = sample_index + 1;
                end
                exp_i[exp_wr_ptr] = normalize_mac(acc_i);
                exp_q[exp_wr_ptr] = normalize_mac(acc_q);
                exp_wr_ptr = exp_wr_ptr + 1;

                acc_i = 0;
                acc_q = 0;
                sample_index = 0;
                for (coeff_idx = 1; coeff_idx < MAX_TAPS; coeff_idx = coeff_idx + 2) begin
                    acc_i = acc_i + hist_i[sample_index] * coeff_ref[coeff_idx];
                    acc_q = acc_q + hist_q[sample_index] * coeff_ref[coeff_idx];
                    sample_index = sample_index + 1;
                end
                exp_i[exp_wr_ptr] = normalize_mac(acc_i);
                exp_q[exp_wr_ptr] = normalize_mac(acc_q);
                exp_wr_ptr = exp_wr_ptr + 1;
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
            while ((exp_rd_ptr < expected_count) && (watchdog < 3000)) begin
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
        load_coeffs();
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_i = 0;
        in_q = 0;
        cfg_bypass = 1'b0;
        reset_dut();

        cfg_bypass = 1'b1;
        push_sample(16'sd1200, -16'sd800);
        push_sample(-16'sd450, 16'sd225);
        push_sample(16'sd75, 16'sd150);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: THB1 bypass case passed with %0d checks", checks);

        reset_dut();
        cfg_bypass = 1'b0;
        push_sample(16'sd4096, -16'sd2048);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        push_sample(16'sd0, 16'sd0);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: THB1 impulse-response case passed with %0d checks", checks);

        reset_dut();
        cfg_bypass = 1'b0;
        push_sample(16'sd1024, 16'sd512);
        push_sample(-16'sd768, 16'sd256);
        push_sample(16'sd384, -16'sd192);
        push_sample(-16'sd192, 16'sd96);
        wait_for_expected_outputs(exp_wr_ptr);
        $display("INFO: THB1 complex-stream case passed with %0d checks", checks);

        $display("INFO: all THB1 RTL tests passed");
        $finish;
    end

endmodule