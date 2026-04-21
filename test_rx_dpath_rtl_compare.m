clear; clc;

repo_root = fileparts(mfilename('fullpath'));
tb_dir = fullfile(repo_root, 'tb');

cfg_file = fullfile(tb_dir, 'rx_dpath_rtl_cfg.txt');
coeff_file = fullfile(tb_dir, 'rx_dpath_rtl_coeff.txt');
input_file = fullfile(tb_dir, 'rx_dpath_rtl_input.txt');
output_file = fullfile(tb_dir, 'rx_dpath_rtl_output.txt');
ref_output_file = fullfile(tb_dir, 'rx_dpath_rtl_ref_output.txt');

cases = build_rx_test_cases();

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
    '.\rtl\rx_fixed_decim_filter_rtl.v', ...
    '.\rtl\rx_pfir_filter_rtl.v', ...
    '.\rtl\rx_dpath_rtl.v', ...
    '.\tb\tb_rx_dpath_rtl_fileio.v'}, ' ');

[status, cmdout] = system(compile_cmd);
if status ~= 0
    error('ModelSim compile failed:\n%s', cmdout);
end

fprintf('Compiled rx_dpath_rtl file-driven testbench successfully.\n');

for case_idx = 1:numel(cases)
    tc = cases(case_idx);
    write_coeff_file(coeff_file, tc.pfir_coeff_q14);
    write_input_file(input_file, tc.input_iq);

    ref_out = rx_dpath_rtl_matlab_reference(tc);
    write_input_file(ref_output_file, ref_out);
    write_cfg_file(cfg_file, tc, size(ref_out, 1));

    if exist(output_file, 'file')
        delete(output_file);
    end

    run_cmd = sprintf('cd /d "%s" && vsim -c tb_rx_dpath_rtl_fileio -do "run -all; quit -f"', repo_root);
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

fprintf('\nAll rx_dpath_rtl ModelSim vs MATLAB comparisons passed.\n');

function cases = build_rx_test_cases()
    pfir24 = zeros(72,1,'int16');
    pfir48 = zeros(72,1,'int16');
    pfir24(1:24) = int16(fir1(23, 0.80) * 16384);
    pfir48(1:48) = int16(fir1(47, 0.80) * 16384);

    cases(1).name = 'dec5_hr_pfir1';
    cases(1).front_path_fir_chain = false;
    cases(1).dec5_bypass = false;
    cases(1).fir2_bypass = false;
    cases(1).fir1_bypass = false;
    cases(1).rhb2_bypass = false;
    cases(1).rhb1_mode_lp = false;
    cases(1).hr_bypass = false;
    cases(1).lp_bypass = false;
    cases(1).pfir_bypass = false;
    cases(1).pfir_decim = uint8(1);
    cases(1).pfir_gain_sel = uint8(1);
    cases(1).pfir_tap_count = uint8(24);
    cases(1).pfir_coeff_q14 = pfir24;
    cases(1).input_iq = int16([1024 512; -512 256; 256 -128; -128 64; 64 32; -32 16; 16 -8; -8 4; 4 2; -2 1]);

    cases(2).name = 'firchain_lp_pfir2';
    cases(2).front_path_fir_chain = true;
    cases(2).dec5_bypass = false;
    cases(2).fir2_bypass = true;
    cases(2).fir1_bypass = true;
    cases(2).rhb2_bypass = false;
    cases(2).rhb1_mode_lp = true;
    cases(2).hr_bypass = false;
    cases(2).lp_bypass = false;
    cases(2).pfir_bypass = false;
    cases(2).pfir_decim = uint8(2);
    cases(2).pfir_gain_sel = uint8(2);
    cases(2).pfir_tap_count = uint8(48);
    cases(2).pfir_coeff_q14 = pfir48;
    cases(2).input_iq = int16([900 -450; -300 150; 80 40; -40 20; 20 -10; -10 5; 5 -2; -2 1; 1 0; 0 1; -1 0; 2 -1]);

    cases(3).name = 'bypass_mix';
    cases(3).front_path_fir_chain = false;
    cases(3).dec5_bypass = true;
    cases(3).fir2_bypass = false;
    cases(3).fir1_bypass = false;
    cases(3).rhb2_bypass = true;
    cases(3).rhb1_mode_lp = false;
    cases(3).hr_bypass = true;
    cases(3).lp_bypass = false;
    cases(3).pfir_bypass = true;
    cases(3).pfir_decim = uint8(4);
    cases(3).pfir_gain_sel = uint8(0);
    cases(3).pfir_tap_count = uint8(24);
    cases(3).pfir_coeff_q14 = pfir24;
    cases(3).input_iq = int16([700 350; -200 100; 50 -25; -10 5; 2 -1; -1 1]);
end

function write_cfg_file(cfg_file, tc, total_outputs)
    fid = fopen(cfg_file, 'w');
    assert(fid ~= -1, 'Failed to open RX cfg file for writing.');
    fprintf(fid, '%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n', ...
        size(tc.input_iq, 1), ...
        total_outputs, ...
        tc.front_path_fir_chain, ...
        tc.dec5_bypass, ...
        tc.fir2_bypass, ...
        tc.fir1_bypass, ...
        tc.rhb2_bypass, ...
        tc.rhb1_mode_lp, ...
        tc.hr_bypass, ...
        tc.lp_bypass, ...
        tc.pfir_bypass, ...
        tc.pfir_decim, ...
        tc.pfir_gain_sel, ...
        tc.pfir_tap_count);
    fclose(fid);
end

function write_coeff_file(coeff_file, coeff_q14)
    fid = fopen(coeff_file, 'w');
    assert(fid ~= -1, 'Failed to open RX coeff file for writing.');
    fprintf(fid, '%d\n', int16(coeff_q14));
    fclose(fid);
end

function write_input_file(input_file, input_iq)
    fid = fopen(input_file, 'w');
    assert(fid ~= -1, 'Failed to open RX input file for writing.');
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

function out = rx_dpath_rtl_matlab_reference(tc)
    coeffs = get_rx_coefficients();
    seq = complex(double(tc.input_iq(:, 1)), double(tc.input_iq(:, 2)));

    if tc.front_path_fir_chain
        seq = run_decim_stage(seq, coeffs.fir12, 2, tc.fir2_bypass, 1);
        seq = run_decim_stage(seq, coeffs.fir12, 2, tc.fir1_bypass, 1);
        seq = run_decim_stage(seq, coeffs.rhb3, 2, false, 1);
    else
        seq = run_decim_stage(seq, coeffs.dec5, 5, tc.dec5_bypass, 1);
    end

    seq = run_decim_stage(seq, coeffs.rhb2, 2, tc.rhb2_bypass, 1);
    if tc.rhb1_mode_lp
        seq = run_decim_stage(seq, coeffs.lp, 2, tc.lp_bypass, 1);
    else
        seq = run_decim_stage(seq, coeffs.hr, 2, tc.hr_bypass, 1);
    end
    seq = run_decim_stage(seq, tc.pfir_coeff_q14(1:double(tc.pfir_tap_count)), double(tc.pfir_decim), tc.pfir_bypass, double(tc.pfir_gain_sel));

    out = int16([real(seq), imag(seq)]);
end

function seq_out = run_decim_stage(seq_in, coeff_q14, decim_factor, bypass, gain_sel)
    hist_len = numel(coeff_q14);
    hist_re = zeros(hist_len, 1, 'int64');
    hist_im = zeros(hist_len, 1, 'int64');
    decim_phase = decim_factor - 1;
    out_re = zeros(max(1, ceil((numel(seq_in) + hist_len - 1) / max(decim_factor,1))), 1, 'int16');
    out_im = zeros(size(out_re), 'int16');
    out_idx = 1;
    coeff_q14 = int64(coeff_q14(:));

    if bypass
        seq_out = complex(double(int16(real(seq_in))), double(int16(imag(seq_in))));
        return;
    end

    for n = 1:(numel(seq_in) + hist_len - 1)
        hist_re(2:end) = hist_re(1:end-1);
        hist_im(2:end) = hist_im(1:end-1);
        if n <= numel(seq_in)
            hist_re(1) = int64(real(seq_in(n)));
            hist_im(1) = int64(imag(seq_in(n)));
        else
            hist_re(1) = 0;
            hist_im(1) = 0;
        end

        if decim_phase >= decim_factor - 1
            acc_re = int64(0);
            acc_im = int64(0);
            for k = 1:hist_len
                acc_re = acc_re + hist_re(k) * coeff_q14(k);
                acc_im = acc_im + hist_im(k) * coeff_q14(k);
            end
            out_re(out_idx) = apply_gain_and_wrap(acc_re, gain_sel);
            out_im(out_idx) = apply_gain_and_wrap(acc_im, gain_sel);
            out_idx = out_idx + 1;
            decim_phase = 0;
        else
            decim_phase = decim_phase + 1;
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

function coeffs = get_rx_coefficients()
    coeffs.fir12 = int16([1024, 4096, 6144, 4096, 1024]);
    coeffs.rhb3 = int16([-544, 0, 4608, 8128, 4608, 0, -544]);
    coeffs.rhb2 = int16([-4, 0, 28, 0, -128, 0, 440, 0, -1284, 0, 5056, 8212, 5056, 0, -1284, 0, 440, 0, -128, 0, 28, 0, -4]);
    coeffs.hr = int16([2,0,-5,0,10,0,-20,0,35,0,-57,0,90,0,-136,0,200,0,-289,0,417,0,-609,0,938,0,-1665,0,5153,8126,5153,0,-1665,0,938,0,-609,0,417,0,-289,0,200,0,-136,0,90,0,-57,0,35,0,-20,0,10,0,-5,0,2]);
    coeffs.lp = int16([-44,0,284,0,-1120,0,4988,8220,4988,0,-1120,0,284,0,-44]);
    coeffs.dec5 = int16([16,20,32,32,-64,-128,-240,-308,-312,-124,176,684,1296,1920,2408,2712,2712,2408,1920,1296,684,176,-124,-312,-308,-240,-128,-64,20,32,32,20,16]);
end