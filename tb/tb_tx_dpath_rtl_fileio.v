`timescale 1ns/1ps

module tb_tx_dpath_rtl_fileio;

    localparam DATA_W = 16;
    localparam COEFF_W = 16;
    localparam ACC_W = 40;
    localparam FRAC_W = 14;
    localparam TFIR_MAX_TAPS = 80;
    localparam MAX_INPUT_SAMPLES = 256;

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

    reg signed [COEFF_W-1:0] coeff_mem [0:TFIR_MAX_TAPS-1];
    reg signed [DATA_W-1:0] input_i_mem [0:MAX_INPUT_SAMPLES-1];
    reg signed [DATA_W-1:0] input_q_mem [0:MAX_INPUT_SAMPLES-1];

    integer cfg_fd;
    integer coeff_fd;
    integer input_fd;
    integer output_fd;
    integer scan_count;
    integer idx;
    integer num_input_samples;
    integer total_output_samples;
    integer out_count;
    integer watchdog;

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

    task read_config;
        integer tmp_path_int5;
        integer tmp_tfir_bypass;
        integer tmp_tfir_interp;
        integer tmp_tfir_gain_sel;
        integer tmp_tfir_tap_count;
        integer tmp_thb1_bypass;
        integer tmp_thb2_bypass;
        integer tmp_thb3_bypass;
        integer tmp_int5_bypass;
        begin
            cfg_fd = $fopen("tb/tx_dpath_rtl_cfg.txt", "r");
            if (cfg_fd == 0) begin
                $display("ERROR: cannot open tb/tx_dpath_rtl_cfg.txt");
                $fatal;
            end

            scan_count = $fscanf(cfg_fd, "%d %d %d %d %d %d %d %d %d %d %d",
                                 num_input_samples,
                                 total_output_samples,
                                 tmp_path_int5,
                                 tmp_tfir_bypass,
                                 tmp_tfir_interp,
                                 tmp_tfir_gain_sel,
                                 tmp_tfir_tap_count,
                                 tmp_thb1_bypass,
                                 tmp_thb2_bypass,
                                 tmp_thb3_bypass,
                                 tmp_int5_bypass);
            $fclose(cfg_fd);

            if (scan_count != 11) begin
                $display("ERROR: malformed config file, fields read = %0d", scan_count);
                $fatal;
            end

            if (num_input_samples > MAX_INPUT_SAMPLES) begin
                $display("ERROR: num_input_samples=%0d exceeds MAX_INPUT_SAMPLES=%0d", num_input_samples, MAX_INPUT_SAMPLES);
                $fatal;
            end

            cfg_path_int5 = tmp_path_int5[0];
            cfg_tfir_bypass = tmp_tfir_bypass[0];
            cfg_tfir_interp = tmp_tfir_interp[2:0];
            cfg_tfir_gain_sel = tmp_tfir_gain_sel[1:0];
            cfg_tfir_tap_count = tmp_tfir_tap_count[6:0];
            cfg_thb1_bypass = tmp_thb1_bypass[0];
            cfg_thb2_bypass = tmp_thb2_bypass[0];
            cfg_thb3_bypass = tmp_thb3_bypass[0];
            cfg_int5_bypass = tmp_int5_bypass[0];
        end
    endtask

    task read_coeffs;
        integer coeff_value;
        begin
            coeff_fd = $fopen("tb/tx_dpath_rtl_coeff.txt", "r");
            if (coeff_fd == 0) begin
                $display("ERROR: cannot open tb/tx_dpath_rtl_coeff.txt");
                $fatal;
            end

            for (idx = 0; idx < TFIR_MAX_TAPS; idx = idx + 1) begin
                scan_count = $fscanf(coeff_fd, "%d", coeff_value);
                if (scan_count != 1) begin
                    $display("ERROR: failed to read TFIR coefficient %0d", idx);
                    $fatal;
                end
                coeff_mem[idx] = coeff_value;
            end

            $fclose(coeff_fd);
        end
    endtask

    task read_inputs;
        integer sample_i_val;
        integer sample_q_val;
        begin
            input_fd = $fopen("tb/tx_dpath_rtl_input.txt", "r");
            if (input_fd == 0) begin
                $display("ERROR: cannot open tb/tx_dpath_rtl_input.txt");
                $fatal;
            end

            for (idx = 0; idx < num_input_samples; idx = idx + 1) begin
                scan_count = $fscanf(input_fd, "%d %d", sample_i_val, sample_q_val);
                if (scan_count != 2) begin
                    $display("ERROR: failed to read input sample %0d", idx);
                    $fatal;
                end
                input_i_mem[idx] = sample_i_val;
                input_q_mem[idx] = sample_q_val;
            end

            $fclose(input_fd);
        end
    endtask

    task program_coeff;
        input [6:0] addr;
        input signed [COEFF_W-1:0] value;
        begin
            @(posedge clk);
            coeff_wr_en <= 1'b1;
            coeff_wr_addr <= addr;
            coeff_wr_data <= value;
            @(posedge clk);
            coeff_wr_en <= 1'b0;
            coeff_wr_addr <= 7'd0;
            coeff_wr_data <= {COEFF_W{1'b0}};
        end
    endtask

    task push_sample;
        input signed [DATA_W-1:0] sample_i_val;
        input signed [DATA_W-1:0] sample_q_val;
        begin
            @(negedge clk);
            while (!in_ready) begin
                @(negedge clk);
            end

            in_valid <= 1'b1;
            in_i <= sample_i_val;
            in_q <= sample_q_val;

            @(posedge clk);
            in_valid <= 1'b0;
            in_i <= {DATA_W{1'b0}};
            in_q <= {DATA_W{1'b0}};
        end
    endtask

    always @(posedge clk) begin
        if (out_valid) begin
            $fdisplay(output_fd, "%0d %0d", out_i, out_q);
            out_count = out_count + 1;
        end
    end

    initial begin
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_i = {DATA_W{1'b0}};
        in_q = {DATA_W{1'b0}};
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
        coeff_wr_addr = 7'd0;
        coeff_wr_data = {COEFF_W{1'b0}};
        out_count = 0;

        read_config();
        read_coeffs();
        read_inputs();

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (idx = 0; idx < TFIR_MAX_TAPS; idx = idx + 1) begin
            program_coeff(idx[6:0], coeff_mem[idx]);
        end

        output_fd = $fopen("tb/tx_dpath_rtl_output.txt", "w");
        if (output_fd == 0) begin
            $display("ERROR: cannot open tb/tx_dpath_rtl_output.txt for writing");
            $fatal;
        end

        for (idx = 0; idx < num_input_samples; idx = idx + 1) begin
            push_sample(input_i_mem[idx], input_q_mem[idx]);
        end

        watchdog = 0;
        while ((out_count < total_output_samples) && (watchdog < 200000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end

        if (out_count != total_output_samples) begin
            $display("ERROR: timeout waiting for outputs. expected=%0d got=%0d", total_output_samples, out_count);
            $fatal;
        end

        $fclose(output_fd);
        $display("INFO: file-driven tx_dpath_rtl run complete, outputs=%0d", out_count);
        $finish;
    end

endmodule