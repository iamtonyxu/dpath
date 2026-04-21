clear; clc;

repo_root = fileparts(mfilename('fullpath'));
tb_dir = fullfile(repo_root, 'tb');

cfg_file = fullfile(tb_dir, 'tx_dpath_rtl_cfg.txt');
coeff_file = fullfile(tb_dir, 'tx_dpath_rtl_coeff.txt');
input_file = fullfile(tb_dir, 'tx_dpath_rtl_input.txt');
output_file = fullfile(tb_dir, 'tx_dpath_rtl_output.txt');

cases = build_test_cases();

work_dir = fullfile(repo_root, 'work');
if ~isfolder(work_dir)
    init_cmd = strjoin({ ...
        'cd /d "' repo_root '"', ...
        '&& vlib work'}, ' ');
    [status, cmdout] = system(init_cmd);
    if status ~= 0
        error('ModelSim work library creation failed:\n%s', cmdout);
    end
end

compile_cmd = strjoin({ ...
    'cd /d "' repo_root '"', ...
    '&& vlog .\rtl\tfir_gain_scale.v', ...
    '.\rtl\tfir_filter_rtl.v', ...
    '.\rtl\thb1_filter_rtl.v', ...
    '.\rtl\thb2_filter_rtl.v', ...
    '.\rtl\thb3_filter_rtl.v', ...
    '.\rtl\int5_filter_rtl.v', ...
    '.\rtl\tx_dpath_rtl.v', ...
    '.\tb\tb_tx_dpath_rtl_fileio.v'}, ' ');

[status, cmdout] = system(compile_cmd);
if status ~= 0
    error('ModelSim compile failed:\n%s', cmdout);
end

fprintf('Compiled tx_dpath_rtl file-driven testbench successfully.\n');

for case_idx = 1:numel(cases)
    tc = cases(case_idx);
    write_coeff_file(coeff_file, tc.tfir_coeff_q14);
    write_input_file(input_file, tc.input_iq);

    ref_out = tx_dpath_rtl_matlab_reference(tc);
    write_cfg_file(cfg_file, tc, size(ref_out, 1));

    if exist(output_file, 'file')
        delete(output_file);
    end

    run_cmd = sprintf('cd /d "%s" && vsim -c tb_tx_dpath_rtl_fileio -do "run -all; quit -f"', repo_root);
    [status, cmdout] = system(run_cmd);
    if status ~= 0
        error('ModelSim run failed for case %s:\n%s', tc.name, cmdout);
    end

    rtl_out = read_output_file(output_file);

    if size(rtl_out, 1) ~= size(ref_out, 1)
        error('Case %s: output length mismatch. RTL=%d MATLAB=%d', tc.name, size(rtl_out, 1), size(ref_out, 1));
    end

    diff_mat = rtl_out - ref_out;
    max_abs_err = max(abs(diff_mat), [], 'all');
    mismatch_rows = find(any(diff_mat ~= 0, 2));

    fprintf('Case %-20s outputs=%3d  max_abs_err=%d\n', tc.name, size(rtl_out, 1), max_abs_err);

    if ~isempty(mismatch_rows)
        first_bad = mismatch_rows(1);
        error(['Case %s mismatch at sample %d: RTL=(%d,%d), MATLAB=(%d,%d)'], ...
            tc.name, first_bad - 1, rtl_out(first_bad, 1), rtl_out(first_bad, 2), ref_out(first_bad, 1), ref_out(first_bad, 2));
    end
end

fprintf('\nAll tx_dpath_rtl ModelSim vs MATLAB comparisons passed.\n');

function cases = build_test_cases()
    coeff_base = zeros(80, 1, 'int16');
    coeff_base(1:8) = int16([8192; 4096; -2048; 1024; 512; -256; 128; -64]);

    cases(1).name = 'thb_path';
    cases(1).path_int5 = false;
    cases(1).tfir_bypass = false;
    cases(1).tfir_interp = uint8(2);
    cases(1).tfir_gain_sel = uint8(1);
    cases(1).tfir_tap_count = uint8(20);
    cases(1).thb1_bypass = false;
    cases(1).thb2_bypass = false;
    cases(1).thb3_bypass = false;
    cases(1).int5_bypass = false;
    cases(1).tfir_coeff_q14 = coeff_base;
    cases(1).input_iq = int16([1024 512; -768 384; 256 -128]);

    cases(2).name = 'int5_path';
    cases(2).path_int5 = true;
    cases(2).tfir_bypass = false;
    cases(2).tfir_interp = uint8(1);
    cases(2).tfir_gain_sel = uint8(2);
    cases(2).tfir_tap_count = uint8(20);
    cases(2).thb1_bypass = false;
    cases(2).thb2_bypass = false;
    cases(2).thb3_bypass = false;
    cases(2).int5_bypass = false;
    cases(2).tfir_coeff_q14 = coeff_base;
    cases(2).input_iq = int16([900 -450; -300 150; 80 40]);

    cases(3).name = 'bypass_mix';
    cases(3).path_int5 = true;
    cases(3).tfir_bypass = true;
    cases(3).tfir_interp = uint8(4);
    cases(3).tfir_gain_sel = uint8(0);
    cases(3).tfir_tap_count = uint8(20);
    cases(3).thb1_bypass = true;
    cases(3).thb2_bypass = false;
    cases(3).thb3_bypass = false;
    cases(3).int5_bypass = true;
    cases(3).tfir_coeff_q14 = coeff_base;
    cases(3).input_iq = int16([700 350; -200 100]);
end

function write_cfg_file(cfg_file, tc, total_outputs)
    fid = fopen(cfg_file, 'w');
    assert(fid ~= -1, 'Failed to open cfg file for writing.');
    fprintf(fid, '%d %d %d %d %d %d %d %d %d %d %d\n', ...
        size(tc.input_iq, 1), ...
        total_outputs, ...
        tc.path_int5, ...
        tc.tfir_bypass, ...
        tc.tfir_interp, ...
        tc.tfir_gain_sel, ...
        tc.tfir_tap_count, ...
        tc.thb1_bypass, ...
        tc.thb2_bypass, ...
        tc.thb3_bypass, ...
        tc.int5_bypass);
    fclose(fid);
end

function write_coeff_file(coeff_file, coeff_q14)
    fid = fopen(coeff_file, 'w');
    assert(fid ~= -1, 'Failed to open coeff file for writing.');
    fprintf(fid, '%d\n', int16(coeff_q14));
    fclose(fid);
end

function write_input_file(input_file, input_iq)
    fid = fopen(input_file, 'w');
    assert(fid ~= -1, 'Failed to open input file for writing.');
    fprintf(fid, '%d %d\n', input_iq.');
    fclose(fid);
end

function rtl_out = read_output_file(output_file)
    raw = readmatrix(output_file, 'FileType', 'text');
    if isempty(raw)
        rtl_out = zeros(0, 2, 'int16');
        return;
    end
    rtl_out = int16(raw(:, 1:2));
end

function out = tx_dpath_rtl_matlab_reference(tc)
    coeffs = get_coefficients();
    seq = complex(double(tc.input_iq(:, 1)), double(tc.input_iq(:, 2)));

    seq = run_stage(seq, tc.tfir_coeff_q14(1:double(tc.tfir_tap_count)), double(tc.tfir_interp), tc.tfir_bypass, false, double(tc.tfir_gain_sel));
    seq = run_stage(seq, coeffs.thb1, 2, tc.thb1_bypass, false, 1);

    if tc.path_int5
        seq = run_stage(seq, coeffs.int5, 5, tc.int5_bypass, true, 1);
    else
        seq = run_stage(seq, coeffs.thb2, 2, tc.thb2_bypass, false, 1);
        seq = run_stage(seq, coeffs.thb3, 2, tc.thb3_bypass, false, 1);
    end

    out = int16([real(seq), imag(seq)]);
end

function seq_out = run_stage(seq_in, coeff_q14, interp_factor, bypass, zero_stuff_bypass, gain_sel)
    hist_len = numel(coeff_q14);
    hist_re = zeros(hist_len, 1, 'int64');
    hist_im = zeros(hist_len, 1, 'int64');
    out_re = zeros(numel(seq_in) * interp_factor, 1, 'int16');
    out_im = zeros(numel(seq_in) * interp_factor, 1, 'int16');
    out_idx = 1;

    coeff_q14 = int64(coeff_q14(:));

    for n = 1:numel(seq_in)
        hist_re(2:end) = hist_re(1:end-1);
        hist_im(2:end) = hist_im(1:end-1);
        hist_re(1) = int64(real(seq_in(n)));
        hist_im(1) = int64(imag(seq_in(n)));

        if bypass
            out_re(out_idx) = wrap_to_int16(hist_re(1));
            out_im(out_idx) = wrap_to_int16(hist_im(1));
            out_idx = out_idx + 1;
            if zero_stuff_bypass
                for phase = 2:interp_factor
                    out_re(out_idx) = int16(0);
                    out_im(out_idx) = int16(0);
                    out_idx = out_idx + 1;
                end
            end
            continue;
        end

        for phase = 0:interp_factor-1
            acc_re = int64(0);
            acc_im = int64(0);
            sample_index = 1;
            for coeff_idx = phase+1:interp_factor:numel(coeff_q14)
                acc_re = acc_re + hist_re(sample_index) * coeff_q14(coeff_idx);
                acc_im = acc_im + hist_im(sample_index) * coeff_q14(coeff_idx);
                sample_index = sample_index + 1;
            end

            if interp_factor == 1 || nargin < 6
                out_re(out_idx) = wrap_to_int16(bitshift(acc_re, -14));
                out_im(out_idx) = wrap_to_int16(bitshift(acc_im, -14));
            else
                out_re(out_idx) = apply_gain_and_wrap(acc_re, gain_sel);
                out_im(out_idx) = apply_gain_and_wrap(acc_im, gain_sel);
            end
            out_idx = out_idx + 1;
        end
    end

    seq_out = complex(double(out_re(1:out_idx-1)), double(out_im(1:out_idx-1)));
end

function y = apply_gain_and_wrap(acc_value, gain_sel)
    switch gain_sel
        case 0
            scaled = bitshift(acc_value, 1);
        case 1
            scaled = acc_value;
        case 2
            scaled = bitshift(acc_value, -1);
        otherwise
            scaled = bitshift(acc_value, -2);
    end
    y = wrap_to_int16(bitshift(scaled, -14));
end

function y = wrap_to_int16(value)
    wrapped = mod(double(value), 2^16);
    if wrapped >= 2^15
        wrapped = wrapped - 2^16;
    end
    y = int16(wrapped);
end

function coeffs = get_coefficients()
    coeffs.thb1 = int16([ ...
       -38, 0, 59, 0, -67, 0, 67, 0, -106, 0, 157, 0, -197, 0, 236, 0, ...
       -307, 0, 398, 0, -492, 0, 612, 0, -789, 0, 1031, 0, -1382, 0, 2004, 0, ...
       -3434, 0, 10419, 16384, 10419, 0, -3434, 0, 2004, 0, -1382, 0, 1031, 0, ...
       -789, 0, 612, 0, -492, 0, 398, 0, -307, 0, 236, 0, -197, 0, 157, 0, ...
       -106, 0, 67, 0, -67, 0, 59, 0, -38]);
    coeffs.thb2 = int16([-1344, 0, 9536, 16384, 9536, 0, -1344]);
    coeffs.thb3 = int16([2048, 8192, 12288, 8192, 2048]);
    coeffs.int5 = int16([ ...
        48, 476, -480, 512, -200, -96, -928, 844, -912, 416, 344, 1332, -944, 1188, -740, -780, ...
        -1572, 500, -1168, 1124, 1540, 1864, 504, 908, -1700, -3044, -3036, -2244, -612, 3720, 8496, 11752, ...
        15212, 16700, 15212, 11752, 8496, 3720, -612, -2244, -3036, -3044, -1700, 908, 504, 1864, 1540, 1124, ...
        -1168, 500, -1572, -780, -740, 1188, -944, 1332, 344, 416, -912, 844, -928, -96, -200, 512, -480, 476, 48]);
end