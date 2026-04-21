% test_tfir_filter.m
% Tests and frequency response plots for the TFIR programmable filter.
%
% The TFIR compensates for post-DAC analog LPF roll-off.  Because the
% coefficients are fully programmable, this script demonstrates the filter
% with three example coefficient sets:
%   1. Flat passband (windowed sinc)   – 20 taps, interp=1
%   2. HF-boost compensation filter    – 40 taps, interp=2
%   3. HF-boost compensation filter    – 80 taps, interp=4
% and verifies all gain settings (+6, 0, -6, -12 dB).

clear; close all; clc;

%% ================================================================== %%
%  Helper: design a DAC-compensation FIR using MATLAB's firls.
%  The post-DAC sinc roll-off is  sinc(f/Fs_dac).  The compensation
%  filter inverts this over a specified passband fraction.
%  tap_count must be 20, 40, 60, or 80.
% ================================================================== %%
function h = design_compensation_fir(tap_count, interp, passband_fraction)
    % Build a desired amplitude profile that rises to compensate sinc droop.
    % frequency normalised to Nyquist of the OUTPUT rate (0=DC, 1=Fs_out/2).
    Npts = 512;
    f    = linspace(0, 1, Npts);

    % Sinc roll-off at the INPUT rate.  At Fs_out = interp*Fs_in, the
    % input Nyquist sits at f = 1/interp (normalised to Fs_out/2).
    % The sinc argument runs 0…pi/2 over 0…Fs_in/2 = 0…1/interp in f.
    f_in_norm = f * interp;          % maps [0,1/interp] -> [0,1]
    sinc_val  = sinc(f_in_norm / 2); % sinc(x/2) for half-Nyquist droop

    % Desired amplitude = inverse sinc in passband, zero in stopband
    pb_edge   = passband_fraction;   % passband up to this fraction of Fs_out/2
    sb_edge   = min(pb_edge + 0.1, 0.95);

    desired   = zeros(1, Npts);
    pb_mask   = f <= pb_edge;
    desired(pb_mask) = 1 ./ max(sinc_val(pb_mask), 0.1);  % cap gain at ×10

    % Normalise so DC desired = 1
    desired = desired / desired(1);

    % Frequency bands and desired values for firls
    f_bands = [0, pb_edge, sb_edge, 1];
    d_bands = [desired(1), desired(round(pb_edge*(Npts-1))+1), 0, 0];

    h = firls(tap_count - 1, f_bands, d_bands);
end

%% ================================================================== %%
%  1.  Flat passband – 20 taps, interp=1, gain=0 dB
% ================================================================== %%
tap_count_1 = 20;
interp_1    = 1;
h1 = fir1(tap_count_1 - 1, 0.8);   % low-pass, cut at 0.8×Nyquist

fprintf('--- TFIR Example 1: %d taps, interp=%d ---\n', tap_count_1, interp_1);
fprintf('  sum(h) = %.4f\n', sum(h1));

%% ================================================================== %%
%  2.  HF-boost compensation – 40 taps, interp=2, gain=-6 dB
% ================================================================== %%
tap_count_2 = 40;
interp_2    = 2;
h2 = design_compensation_fir(tap_count_2, interp_2, 0.4);

fprintf('--- TFIR Example 2: %d taps, interp=%d ---\n', tap_count_2, interp_2);

%% ================================================================== %%
%  3.  HF-boost compensation – 80 taps, interp=4, gain=+6 dB
% ================================================================== %%
tap_count_3 = 80;
interp_3    = 4;
h3 = design_compensation_fir(tap_count_3, interp_3, 0.2);

fprintf('--- TFIR Example 3: %d taps, interp=%d ---\n', tap_count_3, interp_3);

%% ---- Frequency responses --------------------------------------------
N_fft = 8192;

figure('Name','TFIR – Frequency Responses (3 examples)','NumberTitle','off');

configs = { h1, interp_1, 0,  '20-tap, interp×1, 0 dB',  'b'; ...
            h2, interp_2, -6, '40-tap, interp×2, -6 dB', 'm'; ...
            h3, interp_3, +6, '80-tap, interp×4, +6 dB',  'r'};

for k = 1:3
    hk       = configs{k,1};
    gain_db  = configs{k,3};
    label    = configs{k,4};
    color    = configs{k,5};

    gain_lin = 10^(gain_db/20);
    [Hk, wk] = freqz(hk * gain_lin, 1, N_fft, 'whole');
    f_norm_k  = wk/pi - 1;
    Hk_db     = 20*log10(abs(fftshift(Hk)));

    subplot(3,1,k);
    plot(f_norm_k, Hk_db, color, 'LineWidth', 1.2);
    xlabel('Normalised frequency  (× F_{s,out}/2)');
    ylabel('Magnitude (dB)');
    title(['TFIR Magnitude Response – ' label]);
    xlim([-1 1]); ylim([-80 15]); grid on;
end

%% ---- Gain setting verification (+6, 0, -6, -12 dB) -----------------
fprintf('\n--- Gain setting verification (20-tap, interp=1) ---\n');
gain_settings = [6, 0, -6, -12];
Fs_in = 1e6;
N     = 256;
f_tone = 0.1e6;
t_in   = (0:N-1).' / Fs_in;
x_in   = exp(1j * 2*pi * f_tone * t_in);

figure('Name','TFIR – Gain Settings Comparison','NumberTitle','off');
colors_g = {'b','g','m','r'};

for k = 1:4
    gdb = gain_settings(k);
    yk  = tfir_filter(x_in, h1, 1, gdb, false);
    pwr = 20*log10(rms(abs(yk)));
    fprintf('  gain_db = %+3d dB  |  output RMS power: %.2f dB\n', gdb, pwr);

    % Frequency response with gain
    gain_lin = 10^(gdb/20);
    [Hk, wk] = freqz(h1 * gain_lin, 1, N_fft, 'whole');
    f_norm_k  = wk/pi - 1;
    Hk_db     = 20*log10(abs(fftshift(Hk)));

    subplot(2,2,k);
    plot(f_norm_k, Hk_db, colors_g{k}, 'LineWidth', 1.2);
    xlabel('Normalised frequency  (× F_{s,out}/2)');
    ylabel('Magnitude (dB)');
    title(sprintf('TFIR gain = %+d dB', gdb));
    xlim([-1 1]); ylim([-80 15]); grid on;
end

%% ---- Output length check for all interp factors ---------------------
fprintf('\n--- Output length verification ---\n');
interp_vals = [1, 2, 4];
for L = interp_vals
    h_test = fir1(39, 0.8 / L);   % 40-tap, normalised to output rate
    y_norm = tfir_filter(x_in, h_test, L, 0, false);
    y_byp  = tfir_filter(x_in, h_test, L, 0, true);
    fprintf('  interp=%d  normal: %d (expect %d)  bypass: %d (expect %d)\n', ...
            L, length(y_norm), L*N, length(y_byp), N);
end

%% ---- Bypass path validation -----------------------------------------
y_bypass = tfir_filter(x_in, h1, 1, 0, true);
fprintf('\n  bypass output identical to input: %d\n', isequal(y_bypass, x_in));

%% ---- Input validation: wrong tap count --------------------------------
fprintf('\n--- Input validation (expect error for 30 taps) ---\n');
try
    tfir_filter(x_in, ones(1,30), 1, 0, false);
    fprintf('  ERROR: should have thrown an exception\n');
catch e
    fprintf('  Caught expected error: %s\n', e.message);
end

fprintf('\nTest complete.\n');
