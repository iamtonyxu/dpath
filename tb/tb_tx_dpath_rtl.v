`timescale 1ns/1ps

module tb_tx_dpath_rtl;

    localparam DATA_W = 16;
    localparam COEFF_W = 16;
    localparam ACC_W = 40;
    localparam FRAC_W = 14;
    localparam TFIR_MAX_TAPS = 80;

    localparam BANK_TFIR = 3'd0;
    localparam BANK_THB1 = 3'd1;
    localparam BANK_THB2 = 3'd2;
    localparam BANK_THB3 = 3'd3;
    localparam BANK_INT5 = 3'd4;

    reg clk;
    reg rst_n;
    reg in_valid;
    wire in_ready;
    reg signed [DATA_W-1:0] in_i;
    reg signed [DATA_W-1:0] in_q;
    reg cfg_path_int5;
    reg cfg_tfir_bypass;
    reg [2:0] cfg_tfir_interp;
    reg [1:0] cfg_tfir_gain_sel;
    reg [6:0] cfg_tfir_tap_count;
    reg cfg_thb1_bypass;
    reg cfg_thb2_bypass;
    reg cfg_thb3_bypass;
    reg cfg_int5_bypass;
    reg coeff_wr_en;
    reg [6:0] coeff_wr_addr;
    reg signed [COEFF_W-1:0] coeff_wr_data;
    wire out_valid;
    wire signed [DATA_W-1:0] out_i;
    wire signed [DATA_W-1:0] out_q;

    reg signed [COEFF_W-1:0] tfir_coeff_ref [0:TFIR_MAX_TAPS-1];
    reg signed [COEFF_W-1:0] thb1_coeff_ref [0:70];
    reg signed [COEFF_W-1:0] thb2_coeff_ref [0:6];
    reg signed [COEFF_W-1:0] thb3_coeff_ref [0:4];
    reg signed [COEFF_W-1:0] int5_coeff_ref [0:66];

    reg signed [DATA_W-1:0] model_src_i [0:255];
    reg signed [DATA_W-1:0] model_src_q [0:255];
    reg signed [DATA_W-1:0] model_dst_i [0:255];
    reg signed [DATA_W-1:0] model_dst_q [0:255];
    reg signed [DATA_W-1:0] exp_i [0:255];
    reg signed [DATA_W-1:0] exp_q [0:255];

    integer idx;
    integer model_src_count;
    integer model_dst_count;
    integer exp_count;
    integer exp_rd_ptr;
    integer checks;
    integer phase;
    integer coeff_idx;
    integer sample_index;
    reg signed [63:0] acc_i;
    reg signed [63:0] acc_q;

    tx_dpath_rtl #(
        .DATA_W(DATA_W),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W),
        .FRAC_W(FRAC_W),
        .TFIR_MAX_TAPS(TFIR_MAX_TAPS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_i(in_i),
        .in_q(in_q),
        .cfg_path_int5(cfg_path_int5),
        .cfg_tfir_bypass(cfg_tfir_bypass),
        .cfg_tfir_interp(cfg_tfir_interp),
        .cfg_tfir_gain_sel(cfg_tfir_gain_sel),
        .cfg_tfir_tap_count(cfg_tfir_tap_count),
        .cfg_thb1_bypass(cfg_thb1_bypass),
        .cfg_thb2_bypass(cfg_thb2_bypass),
        .cfg_thb3_bypass(cfg_thb3_bypass),
        .cfg_int5_bypass(cfg_int5_bypass),
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

    function signed [COEFF_W-1:0] coeff_lookup;
        input [2:0] bank;
        input integer tap;
        begin
            case (bank)
                BANK_TFIR: coeff_lookup = tfir_coeff_ref[tap];
                BANK_THB1: coeff_lookup = thb1_coeff_ref[tap];
                BANK_THB2: coeff_lookup = thb2_coeff_ref[tap];
                BANK_THB3: coeff_lookup = thb3_coeff_ref[tap];
                default: coeff_lookup = int5_coeff_ref[tap];
            endcase
        end
    endfunction

    function signed [DATA_W-1:0] normalize_value;
        input signed [63:0] value;
        reg signed [63:0] normalized;
        begin
            normalized = value >>> FRAC_W;
            normalize_value = normalized[DATA_W-1:0];
        end
    endfunction

    function signed [DATA_W-1:0] apply_gain;
        input signed [63:0] value;
        input [1:0] gain_sel;
        reg signed [63:0] scaled;
        begin
            case (gain_sel)
                2'd0: scaled = value <<< 1;
                2'd1: scaled = value;
                2'd2: scaled = value >>> 1;
                default: scaled = value >>> 2;
            endcase
            apply_gain = normalize_value(scaled);
        end
    endfunction

    task init_coeffs;
        begin
            for (idx = 0; idx < TFIR_MAX_TAPS; idx = idx + 1) begin
                tfir_coeff_ref[idx] = 0;
            end

            thb1_coeff_ref[0]  = -16'sd38;
            thb1_coeff_ref[1]  = 16'sd0;
            thb1_coeff_ref[2]  = 16'sd59;
            thb1_coeff_ref[3]  = 16'sd0;
            thb1_coeff_ref[4]  = -16'sd67;
            thb1_coeff_ref[5]  = 16'sd0;
            thb1_coeff_ref[6]  = 16'sd67;
            thb1_coeff_ref[7]  = 16'sd0;
            thb1_coeff_ref[8]  = -16'sd106;
            thb1_coeff_ref[9]  = 16'sd0;
            thb1_coeff_ref[10] = 16'sd157;
            thb1_coeff_ref[11] = 16'sd0;
            thb1_coeff_ref[12] = -16'sd197;
            thb1_coeff_ref[13] = 16'sd0;
            thb1_coeff_ref[14] = 16'sd236;
            thb1_coeff_ref[15] = 16'sd0;
            thb1_coeff_ref[16] = -16'sd307;
            thb1_coeff_ref[17] = 16'sd0;
            thb1_coeff_ref[18] = 16'sd398;
            thb1_coeff_ref[19] = 16'sd0;
            thb1_coeff_ref[20] = -16'sd492;
            thb1_coeff_ref[21] = 16'sd0;
            thb1_coeff_ref[22] = 16'sd612;
            thb1_coeff_ref[23] = 16'sd0;
            thb1_coeff_ref[24] = -16'sd789;
            thb1_coeff_ref[25] = 16'sd0;
            thb1_coeff_ref[26] = 16'sd1031;
            thb1_coeff_ref[27] = 16'sd0;
            thb1_coeff_ref[28] = -16'sd1382;
            thb1_coeff_ref[29] = 16'sd0;
            thb1_coeff_ref[30] = 16'sd2004;
            thb1_coeff_ref[31] = 16'sd0;
            thb1_coeff_ref[32] = -16'sd3434;
            thb1_coeff_ref[33] = 16'sd0;
            thb1_coeff_ref[34] = 16'sd10419;
            thb1_coeff_ref[35] = 16'sd16384;
            thb1_coeff_ref[36] = 16'sd10419;
            thb1_coeff_ref[37] = 16'sd0;
            thb1_coeff_ref[38] = -16'sd3434;
            thb1_coeff_ref[39] = 16'sd0;
            thb1_coeff_ref[40] = 16'sd2004;
            thb1_coeff_ref[41] = 16'sd0;
            thb1_coeff_ref[42] = -16'sd1382;
            thb1_coeff_ref[43] = 16'sd0;
            thb1_coeff_ref[44] = 16'sd1031;
            thb1_coeff_ref[45] = 16'sd0;
            thb1_coeff_ref[46] = -16'sd789;
            thb1_coeff_ref[47] = 16'sd0;
            thb1_coeff_ref[48] = 16'sd612;
            thb1_coeff_ref[49] = 16'sd0;
            thb1_coeff_ref[50] = -16'sd492;
            thb1_coeff_ref[51] = 16'sd0;
            thb1_coeff_ref[52] = 16'sd398;
            thb1_coeff_ref[53] = 16'sd0;
            thb1_coeff_ref[54] = -16'sd307;
            thb1_coeff_ref[55] = 16'sd0;
            thb1_coeff_ref[56] = 16'sd236;
            thb1_coeff_ref[57] = 16'sd0;
            thb1_coeff_ref[58] = -16'sd197;
            thb1_coeff_ref[59] = 16'sd0;
            thb1_coeff_ref[60] = 16'sd157;
            thb1_coeff_ref[61] = 16'sd0;
            thb1_coeff_ref[62] = -16'sd106;
            thb1_coeff_ref[63] = 16'sd0;
            thb1_coeff_ref[64] = 16'sd67;
            thb1_coeff_ref[65] = 16'sd0;
            thb1_coeff_ref[66] = -16'sd67;
            thb1_coeff_ref[67] = 16'sd0;
            thb1_coeff_ref[68] = 16'sd59;
            thb1_coeff_ref[69] = 16'sd0;
            thb1_coeff_ref[70] = -16'sd38;

            thb2_coeff_ref[0] = -16'sd1344;
            thb2_coeff_ref[1] = 16'sd0;
            thb2_coeff_ref[2] = 16'sd9536;
            thb2_coeff_ref[3] = 16'sd16384;
            thb2_coeff_ref[4] = 16'sd9536;
            thb2_coeff_ref[5] = 16'sd0;
            thb2_coeff_ref[6] = -16'sd1344;

            thb3_coeff_ref[0] = 16'sd2048;
            thb3_coeff_ref[1] = 16'sd8192;
            thb3_coeff_ref[2] = 16'sd12288;
            thb3_coeff_ref[3] = 16'sd8192;
            thb3_coeff_ref[4] = 16'sd2048;

            int5_coeff_ref[0] = 16'sd48;
            int5_coeff_ref[1] = 16'sd476;
            int5_coeff_ref[2] = -16'sd480;
            int5_coeff_ref[3] = 16'sd512;
            int5_coeff_ref[4] = -16'sd200;
            int5_coeff_ref[5] = -16'sd96;
            int5_coeff_ref[6] = -16'sd928;
            int5_coeff_ref[7] = 16'sd844;
            int5_coeff_ref[8] = -16'sd912;
            int5_coeff_ref[9] = 16'sd416;
            int5_coeff_ref[10] = 16'sd344;
            int5_coeff_ref[11] = 16'sd1332;
            int5_coeff_ref[12] = -16'sd944;
            int5_coeff_ref[13] = 16'sd1188;
            int5_coeff_ref[14] = -16'sd740;
            int5_coeff_ref[15] = -16'sd780;
            int5_coeff_ref[16] = -16'sd1572;
            int5_coeff_ref[17] = 16'sd500;
            int5_coeff_ref[18] = -16'sd1168;
            int5_coeff_ref[19] = 16'sd1124;
            int5_coeff_ref[20] = 16'sd1540;
            int5_coeff_ref[21] = 16'sd1864;
            int5_coeff_ref[22] = 16'sd504;
            int5_coeff_ref[23] = 16'sd908;
            int5_coeff_ref[24] = -16'sd1700;
            int5_coeff_ref[25] = -16'sd3044;
            int5_coeff_ref[26] = -16'sd3036;
            int5_coeff_ref[27] = -16'sd2244;
            int5_coeff_ref[28] = -16'sd612;
            int5_coeff_ref[29] = 16'sd3720;
            int5_coeff_ref[30] = 16'sd8496;
            int5_coeff_ref[31] = 16'sd11752;
            int5_coeff_ref[32] = 16'sd15212;
            int5_coeff_ref[33] = 16'sd16700;
            int5_coeff_ref[34] = 16'sd15212;
            int5_coeff_ref[35] = 16'sd11752;
            int5_coeff_ref[36] = 16'sd8496;
            int5_coeff_ref[37] = 16'sd3720;
            int5_coeff_ref[38] = -16'sd612;
            int5_coeff_ref[39] = -16'sd2244;
            int5_coeff_ref[40] = -16'sd3036;
            int5_coeff_ref[41] = -16'sd3044;
            int5_coeff_ref[42] = -16'sd1700;
            int5_coeff_ref[43] = 16'sd908;
            int5_coeff_ref[44] = 16'sd504;
            int5_coeff_ref[45] = 16'sd1864;
            int5_coeff_ref[46] = 16'sd1540;
            int5_coeff_ref[47] = 16'sd1124;
            int5_coeff_ref[48] = -16'sd1168;
            int5_coeff_ref[49] = 16'sd500;
            int5_coeff_ref[50] = -16'sd1572;
            int5_coeff_ref[51] = -16'sd780;
            int5_coeff_ref[52] = -16'sd740;
            int5_coeff_ref[53] = 16'sd1188;
            int5_coeff_ref[54] = -16'sd944;
            int5_coeff_ref[55] = 16'sd1332;
            int5_coeff_ref[56] = 16'sd344;
            int5_coeff_ref[57] = 16'sd416;
            int5_coeff_ref[58] = -16'sd912;
            int5_coeff_ref[59] = 16'sd844;
            int5_coeff_ref[60] = -16'sd928;
            int5_coeff_ref[61] = -16'sd96;
            int5_coeff_ref[62] = -16'sd200;
            int5_coeff_ref[63] = 16'sd512;
            int5_coeff_ref[64] = -16'sd480;
            int5_coeff_ref[65] = 16'sd476;
            int5_coeff_ref[66] = 16'sd48;
        end
    endtask

    task program_tfir_coeff;
        input [6:0] addr;
        input signed [COEFF_W-1:0] value;
        begin
            @(posedge clk);
            coeff_wr_en <= 1'b1;
            coeff_wr_addr <= addr;
            coeff_wr_data <= value;
            tfir_coeff_ref[addr] = value;
            @(posedge clk);
            coeff_wr_en <= 1'b0;
            coeff_wr_addr <= 0;
            coeff_wr_data <= 0;
        end
    endtask

    task reset_testbench_model;
        begin
            model_src_count = 0;
            model_dst_count = 0;
            exp_count = 0;
            exp_rd_ptr = 0;
            checks = 0;
            for (idx = 0; idx < 256; idx = idx + 1) begin
                model_src_i[idx] = 0;
                model_src_q[idx] = 0;
                model_dst_i[idx] = 0;
                model_dst_q[idx] = 0;
                exp_i[idx] = 0;
                exp_q[idx] = 0;
            end
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            in_valid = 1'b0;
            in_i = 0;
            in_q = 0;
            cfg_path_int5 = 1'b0;
            cfg_tfir_bypass = 1'b0;
            cfg_tfir_interp = 3'd1;
            cfg_tfir_gain_sel = 2'd1;
            cfg_tfir_tap_count = 7'd20;
            cfg_thb1_bypass = 1'b0;
            cfg_thb2_bypass = 1'b0;
            cfg_thb3_bypass = 1'b0;
            cfg_int5_bypass = 1'b0;
            coeff_wr_en = 1'b0;
            coeff_wr_addr = 0;
            coeff_wr_data = 0;
            reset_testbench_model();
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task reload_tfir_coeffs;
        begin
            program_tfir_coeff(7'd0, 16'sd8192);
            program_tfir_coeff(7'd1, 16'sd4096);
            program_tfir_coeff(7'd2, -16'sd2048);
            program_tfir_coeff(7'd3, 16'sd1024);
        end
    endtask

    task model_stage;
        input integer src_count;
        input integer tap_count;
        input integer interp_factor;
        input integer bypass_mode;
        input [2:0] bank;
        input [1:0] gain_sel;
        begin
            model_dst_count = 0;
            if (bypass_mode == 1) begin
                for (idx = 0; idx < src_count; idx = idx + 1) begin
                    model_dst_i[idx] = model_src_i[idx];
                    model_dst_q[idx] = model_src_q[idx];
                end
                model_dst_count = src_count;
            end else if (bypass_mode == 2) begin
                for (idx = 0; idx < src_count; idx = idx + 1) begin
                    model_dst_i[model_dst_count] = model_src_i[idx];
                    model_dst_q[model_dst_count] = model_src_q[idx];
                    model_dst_count = model_dst_count + 1;
                    for (phase = 1; phase < interp_factor; phase = phase + 1) begin
                        model_dst_i[model_dst_count] = 0;
                        model_dst_q[model_dst_count] = 0;
                        model_dst_count = model_dst_count + 1;
                    end
                end
            end else begin
                for (idx = 0; idx < src_count; idx = idx + 1) begin
                    for (phase = 0; phase < interp_factor; phase = phase + 1) begin
                        acc_i = 0;
                        acc_q = 0;
                        sample_index = 0;
                        for (coeff_idx = phase; coeff_idx < tap_count; coeff_idx = coeff_idx + interp_factor) begin
                            if ((idx - sample_index) >= 0) begin
                                acc_i = acc_i + model_src_i[idx - sample_index] * coeff_lookup(bank, coeff_idx);
                                acc_q = acc_q + model_src_q[idx - sample_index] * coeff_lookup(bank, coeff_idx);
                            end
                            sample_index = sample_index + 1;
                        end
                        if (bank == BANK_TFIR) begin
                            model_dst_i[model_dst_count] = apply_gain(acc_i, gain_sel);
                            model_dst_q[model_dst_count] = apply_gain(acc_q, gain_sel);
                        end else begin
                            model_dst_i[model_dst_count] = normalize_value(acc_i);
                            model_dst_q[model_dst_count] = normalize_value(acc_q);
                        end
                        model_dst_count = model_dst_count + 1;
                    end
                end
            end
        end
    endtask

    task advance_model_stage;
        begin
            model_src_count = model_dst_count;
            for (idx = 0; idx < model_dst_count; idx = idx + 1) begin
                model_src_i[idx] = model_dst_i[idx];
                model_src_q[idx] = model_dst_q[idx];
            end
        end
    endtask

    task build_expected_thb_path;
        begin
            model_stage(model_src_count, cfg_tfir_tap_count, (cfg_tfir_interp == 3'd2) ? 2 : ((cfg_tfir_interp == 3'd4) ? 4 : 1), cfg_tfir_bypass ? 1 : 0, BANK_TFIR, cfg_tfir_gain_sel);
            advance_model_stage();
            model_stage(model_src_count, 71, 2, cfg_thb1_bypass ? 1 : 0, BANK_THB1, 2'd1);
            advance_model_stage();
            model_stage(model_src_count, 7, 2, cfg_thb2_bypass ? 1 : 0, BANK_THB2, 2'd1);
            advance_model_stage();
            model_stage(model_src_count, 5, 2, cfg_thb3_bypass ? 1 : 0, BANK_THB3, 2'd1);
            advance_model_stage();
            exp_count = model_src_count;
            for (idx = 0; idx < exp_count; idx = idx + 1) begin
                exp_i[idx] = model_src_i[idx];
                exp_q[idx] = model_src_q[idx];
            end
        end
    endtask

    task build_expected_int5_path;
        begin
            model_stage(model_src_count, cfg_tfir_tap_count, (cfg_tfir_interp == 3'd2) ? 2 : ((cfg_tfir_interp == 3'd4) ? 4 : 1), cfg_tfir_bypass ? 1 : 0, BANK_TFIR, cfg_tfir_gain_sel);
            advance_model_stage();
            model_stage(model_src_count, 71, 2, cfg_thb1_bypass ? 1 : 0, BANK_THB1, 2'd1);
            advance_model_stage();
            model_stage(model_src_count, 67, 5, cfg_int5_bypass ? 2 : 0, BANK_INT5, 2'd1);
            advance_model_stage();
            exp_count = model_src_count;
            for (idx = 0; idx < exp_count; idx = idx + 1) begin
                exp_i[idx] = model_src_i[idx];
                exp_q[idx] = model_src_q[idx];
            end
        end
    endtask

    task push_top_sample;
        input signed [DATA_W-1:0] sample_i_in;
        input signed [DATA_W-1:0] sample_q_in;
        begin
            model_src_count = 1;
            model_src_i[0] = sample_i_in;
            model_src_q[0] = sample_q_in;

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

    task wait_for_outputs;
        input integer expected_count;
        integer watchdog;
        begin
            watchdog = 0;
            while ((exp_rd_ptr < expected_count) && (watchdog < 15000)) begin
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
            if (exp_rd_ptr >= exp_count) begin
                $display("ERROR: unexpected top-level output %0d", exp_rd_ptr);
                $fatal;
            end

            if ((out_i !== exp_i[exp_rd_ptr]) || (out_q !== exp_q[exp_rd_ptr])) begin
                $display("ERROR: top-level sample %0d mismatch: got (%0d,%0d) expect (%0d,%0d)",
                         exp_rd_ptr, out_i, out_q, exp_i[exp_rd_ptr], exp_q[exp_rd_ptr]);
                $fatal;
            end

            checks = checks + 1;
            exp_rd_ptr = exp_rd_ptr + 1;
        end
    end

    initial begin
        init_coeffs();
        reset_dut();
        reload_tfir_coeffs();

        cfg_path_int5 = 1'b0;
        cfg_tfir_bypass = 1'b0;
        cfg_tfir_interp = 3'd2;
        cfg_tfir_gain_sel = 2'd1;
        cfg_tfir_tap_count = 7'd20;
        cfg_thb1_bypass = 1'b0;
        cfg_thb2_bypass = 1'b0;
        cfg_thb3_bypass = 1'b0;
        cfg_int5_bypass = 1'b0;
        push_top_sample(16'sd1024, 16'sd512);
        build_expected_thb_path();
        wait_for_outputs(exp_count);
        $display("INFO: tx_dpath THB-path case passed with %0d checks", checks);

        reset_dut();
        reload_tfir_coeffs();
        cfg_path_int5 = 1'b1;
        cfg_tfir_bypass = 1'b0;
        cfg_tfir_interp = 3'd1;
        cfg_tfir_gain_sel = 2'd2;
        cfg_tfir_tap_count = 7'd20;
        cfg_thb1_bypass = 1'b0;
        cfg_thb2_bypass = 1'b0;
        cfg_thb3_bypass = 1'b0;
        cfg_int5_bypass = 1'b0;
        push_top_sample(16'sd900, -16'sd450);
        build_expected_int5_path();
        wait_for_outputs(exp_count);
        $display("INFO: tx_dpath INT5-path case passed with %0d checks", checks);

        reset_dut();
        reload_tfir_coeffs();
        cfg_path_int5 = 1'b1;
        cfg_tfir_bypass = 1'b1;
        cfg_tfir_interp = 3'd4;
        cfg_tfir_gain_sel = 2'd0;
        cfg_tfir_tap_count = 7'd20;
        cfg_thb1_bypass = 1'b1;
        cfg_thb2_bypass = 1'b0;
        cfg_thb3_bypass = 1'b0;
        cfg_int5_bypass = 1'b1;
        push_top_sample(16'sd700, 16'sd350);
        build_expected_int5_path();
        wait_for_outputs(exp_count);
        $display("INFO: tx_dpath bypass-mix case passed with %0d checks", checks);

        $display("INFO: all tx_dpath top-level smoke tests passed");
        $finish;
    end

endmodule