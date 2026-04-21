% test_tx_dpath.m
% Tests and frequency response plots for the complete Tx digital path.
%
% Configurations tested:
%   Case 1 – THB path, all stages active:  TFIR(×1) → THB1 → THB2 → THB3  (×8)
%   Case 2 – THB path, THB3 bypassed:      TFIR(×1) → THB1 → THB2          (×4)
%   Case 3 – THB path, THB2+THB3 bypassed: TFIR(×1) → THB1                 (×2)
%   Case 4 – INT5 path, all stages active: TFIR(×2) → THB1 → INT5          (×20)
%   Case 5 – INT5 path, THB1 bypassed:     TFIR(×1) → INT5                 (×5)
%   Case 6 – TFIR(×4) → THB1 → THB2 → THB3                                (×32)

clear; close all; clc;

%% ================================================================== %%
%  Shared TFIR coefficient sets (flat LPF, various tap counts)
% ================================================================== %%
% Fs_in = 245.76 MHz, signal BW = 200 MHz  → passband edge = 100 MHz
% Cutoff normalised to output Nyquist = Fs_out/2 = (interp*Fs_in)/2
Fs_in_hz  = 245.76e6;
BW_edge   = 100e6;   % one-sided passband edge (half of 200 MHz BW)

% 20-tap TFIR, interp=1  (Fs_out/2 = 122.88 MHz, fc_norm = 100/122.88 ≈ 0.814)
h_tfir_20 = fir1(19, BW_edge / (Fs_in_hz/2));

% 40-tap TFIR, interp=2  (Fs_out/2 = 245.76 MHz, fc_norm = 100/245.76 ≈ 0.407)
h_tfir_40 = fir1(39, BW_edge / Fs_in_hz);

% 80-tap TFIR, interp=4  (Fs_out/2 = 491.52 MHz, fc_norm = 100/491.52 ≈ 0.203)
h_tfir_80 = fir1(79, BW_edge / (2*Fs_in_hz));

%% ================================================================== %%
%  Build test configurations
% ================================================================== %%
cases = struct();

% Case 1: THB path, all active, TFIR×1
cases(1).label        = 'THB path  (TFIR×1 → THB1 → THB2 → THB3,  total ×8)';
cases(1).cfg.path          = 'THB';
cases(1).cfg.tfir_h        = h_tfir_20;
cases(1).cfg.tfir_interp   = 1;
cases(1).cfg.tfir_gain_db  = 0;
cases(1).cfg.tfir_bypass   = false;
cases(1).cfg.thb1_bypass   = false;
cases(1).cfg.thb2_bypass   = false;
cases(1).cfg.thb3_bypass   = false;

% Case 2: THB path, THB3 bypassed
cases(2).label        = 'THB path  (TFIR×1 → THB1 → THB2,  total ×4)';
cases(2).cfg          = cases(1).cfg;
cases(2).cfg.thb3_bypass = true;

% Case 3: THB path, THB2+THB3 bypassed
cases(3).label        = 'THB path  (TFIR×1 → THB1,  total ×2)';
cases(3).cfg          = cases(1).cfg;
cases(3).cfg.thb2_bypass = true;
cases(3).cfg.thb3_bypass = true;

% Case 4: INT5 path, TFIR×2 + THB1
cases(4).label        = 'INT5 path  (TFIR×2 → THB1 → INT5,  total ×20)';
cases(4).cfg.path          = 'INT5';
cases(4).cfg.tfir_h        = h_tfir_40;
cases(4).cfg.tfir_interp   = 2;
cases(4).cfg.tfir_gain_db  = 0;
cases(4).cfg.tfir_bypass   = false;
cases(4).cfg.thb1_bypass   = false;
cases(4).cfg.int5_bypass   = false;

% Case 5: INT5 path, THB1 bypassed, TFIR×1
cases(5).label        = 'INT5 path  (TFIR×1 → INT5 [THB1 bypassed],  total ×5)';
cases(5).cfg          = cases(4).cfg;
cases(5).cfg.tfir_h       = h_tfir_20;
cases(5).cfg.tfir_interp  = 1;
cases(5).cfg.thb1_bypass  = true;

% Case 6: THB path, TFIR×4
cases(6).label        = 'THB path  (TFIR×4 → THB1 → THB2 → THB3,  total ×32)';
cases(6).cfg.path          = 'THB';
cases(6).cfg.tfir_h        = h_tfir_80;
cases(6).cfg.tfir_interp   = 4;
cases(6).cfg.tfir_gain_db  = 0;
cases(6).cfg.tfir_bypass   = false;
cases(6).cfg.thb1_bypass   = false;
cases(6).cfg.thb2_bypass   = false;
cases(6).cfg.thb3_bypass   = false;

%% ================================================================== %%
%  Frequency response via impulse response method
%  Feed a unit impulse → capture output → FFT → magnitude response
% ================================================================== %%
Fs_in   = 245.76e6;  % 245.76 MHz input sample rate
N_imp   = 512;       % impulse response capture length (input samples)

fprintf('%-60s  %s\n', 'Configuration', 'Total interp');
fprintf('%s\n', repmat('-',1,75));

n_cases = numel(cases);
figure('Name','Tx Digital Path – Frequency Responses','NumberTitle','off', ...
       'Position',[100 50 1100 900]);

colors = {'b','r','g','m','c','k'};

for k = 1:n_cases
    % Build impulse at input rate
    imp    = zeros(N_imp, 1);
    imp(1) = 1;

    [h_imp, Fs_out, info] = tx_dpath(imp, Fs_in, cases(k).cfg);

    fprintf('%-60s  ×%-4g  (Fs_out = %.2f MHz)\n', ...
            cases(k).label, info.total_interp, Fs_out/1e6);

    % Magnitude response (normalised frequency at output rate)
    N_fft  = max(4096, 2*length(h_imp));
    H      = fft(h_imp, N_fft);
    H_db   = 20*log10(abs(fftshift(H)) + eps);
    f_norm = linspace(-1, 1, N_fft);   % -1…+1  (× Fs_out/2)

    subplot(3, 2, k);
    plot(f_norm, H_db, colors{k}, 'LineWidth', 1.2);
    xlabel('Normalised frequency  (× F_{s,out}/2)');
    ylabel('Magnitude (dB)');
    title(cases(k).label, 'FontSize', 8);
    xlim([-1 1]);
    %ylim([-250 10]);
    grid on;
    % Mark passband edge: 1/total_interp of Fs_out/2
    pb = 1 / info.total_interp;
    xline( pb, 'r--'); xline(-pb, 'r--');
end

sgtitle('Tx Digital Path – Frequency Response (all configurations)', 'FontSize', 11);

%% ================================================================== %%
%  Overlay comparison: Cases 1-3 (THB path family)
% ================================================================== %%
figure('Name','Tx Path – THB path family comparison','NumberTitle','off');

labels_overlay = {};
for k = 1:3
    imp    = zeros(N_imp, 1);  imp(1) = 1;
    [h_imp, Fs_out_k, info_k] = tx_dpath(imp, Fs_in, cases(k).cfg);
    N_fft  = 4096;
    H_db   = 20*log10(abs(fftshift(fft(h_imp, N_fft))) + eps);
    f_norm = linspace(-1, 1, N_fft);
    plot(f_norm, H_db, colors{k}, 'LineWidth', 1.2); hold on;
    labels_overlay{k} = sprintf('×%g  %s', info_k.total_interp, cases(k).label(11:end));
end
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('THB Path Family – Magnitude Response Overlay');
xlim([-1 1]); %ylim([-250 10]); 
grid on; legend(labels_overlay, 'Location','southwest');

%% ================================================================== %%
%  Signal processing test: 200 MHz wideband complex baseband signal
%  Generate white noise, then bandlimit to ±100 MHz (BW = 200 MHz)
%  using a 256-tap FIR LPF.  Cutoff_norm = 100 MHz / (Fs_in/2) = 100/122.88 ≈ 0.814
% ================================================================== %%
fprintf('\n--- Signal processing test ---\n');
N_sig     = 1024;
BW        = 200e6;                            % desired signal bandwidth
rng(42);                                       % reproducible
x_raw     = (randn(N_sig,1) + 1j*randn(N_sig,1)) / sqrt(2);
h_bw      = fir1(255, BW_edge / (Fs_in/2));   % 256-tap LPF, fc_norm = 100/122.88
x_in      = filter(h_bw, 1, x_raw);           % bandlimited wideband input

fprintf('%-60s  %-12s  %-12s  %-12s\n', 'Config', 'Len in', 'Len out', 'Expect');
fprintf('%s\n', repmat('-', 1, 100));

for k = 1:n_cases
    [y_out, Fs_out_k, info_k] = tx_dpath(x_in, Fs_in, cases(k).cfg);
    N_expect = info_k.total_interp * N_sig;
    ok = (length(y_out) == N_expect);
    fprintf('%-60s  %-12d  %-12d  %-12d  %s\n', ...
            cases(k).label, N_sig, length(y_out), N_expect, ...
            conditional_str(ok, 'PASS', 'FAIL'));
end

%% ================================================================== %%
%  Input vs output spectrum (Case 1 and Case 4)
% ================================================================== %%
figure('Name','Tx Path – Input vs Output Spectrum','NumberTitle','off');

for row = 1:2
    k      = [1, 4];
    c      = k(row);
    [y_out, Fs_out_c, info_c] = tx_dpath(x_in, Fs_in, cases(c).cfg);

    win_in  = blackman(N_sig);
    win_out = blackman(length(y_out));
    Y_in    = fftshift(fft(x_in  .* win_in));
    Y_out   = fftshift(fft(y_out .* win_out));
    f_in    = (-N_sig/2 : N_sig/2-1)             * Fs_in   / N_sig;
    f_out   = (-length(y_out)/2 : length(y_out)/2-1) * Fs_out_c / length(y_out);

    subplot(2, 2, (row-1)*2 + 1);
    plot(f_in/1e6, 20*log10(abs(Y_in)/max(abs(Y_in))+eps), 'b', 'LineWidth', 1.0);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Input  (Fs=%.2f MHz,  BW=200 MHz)', Fs_in/1e6));
    xlim([-Fs_in/2e6  Fs_in/2e6]); ylim([-250 10]); grid on;
    xline( BW/2e6, 'r--', '+BW/2'); xline(-BW/2e6, 'r--', '-BW/2');

    subplot(2, 2, (row-1)*2 + 2);
    plot(f_out/1e6, 20*log10(abs(Y_out)/max(abs(Y_out))+eps), colors{c}, 'LineWidth', 1.0);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Output – %s\n(Fs=%.2f MHz, ×%g)', ...
          cases(c).label, Fs_out_c/1e6, info_c.total_interp), 'FontSize', 7);
    xlim([-Fs_out_c/2e6  Fs_out_c/2e6]); ylim([-250 10]); grid on;
end
sgtitle('Input vs Output Spectrum  (200 MHz wideband signal)', 'FontSize', 11);

%% ================================================================== %%
%  Input vs output amplitude-frequency plot with x-axis [0, Fs_out]
%  (shown for Case 1 and Case 4)
% ================================================================== %%
figure('Name','Tx Path – Amplitude-Frequency [0, Fs_out]','NumberTitle','off');

cases_plot = [1, 4];
for row = 1:2
    c = cases_plot(row);
    [y_out, Fs_out_c, info_c] = tx_dpath(x_in, Fs_in, cases(c).cfg);

    N_in  = length(x_in);
    N_out = length(y_out);

    win_in   = blackman(N_in);
    win_out  = blackman(N_out);
    Y_in_ss  = fft(x_in  .* win_in);
    Y_out_ss = fft(y_out .* win_out);

    f_in_ss  = (0:N_in-1)   * Fs_in    / N_in;
    f_out_ss = (0:N_out-1)  * Fs_out_c / N_out;

    Y_in_db  = 20*log10(abs(Y_in_ss)  / max(abs(Y_in_ss))  + eps);
    Y_out_db = 20*log10(abs(Y_out_ss) / max(abs(Y_out_ss)) + eps);

    subplot(2,2,(row-1)*2 + 1);
    plot(f_in_ss/1e6, Y_in_db, 'b', 'LineWidth', 1.0);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Input  (Fs=%.2f MHz, BW=200 MHz)', Fs_in/1e6));
    xlim([0 Fs_in/1e6]); ylim([-250 10]); grid on;
    xline(BW_edge/1e6, 'r--', '+BW/2');
    xline((Fs_in-BW_edge)/1e6, 'r--', 'Fs_{in}-BW/2');

    subplot(2,2,(row-1)*2 + 2);
    plot(f_out_ss/1e6, Y_out_db, colors{c}, 'LineWidth', 1.0);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Output – %s\n(Fs=%.2f MHz, ×%g)', ...
          cases(c).label, Fs_out_c/1e6, info_c.total_interp), 'FontSize', 7);
    xlim([0 Fs_out_c/1e6]); ylim([-250 10]); grid on;
    xline(BW_edge/1e6, 'r--', '+BW/2');
end
sgtitle('Amplitude-Frequency Response  [0, Fs_{out}]', 'FontSize', 11);

%% ================================================================== %%
%  Print rate breakdown for each case
% ================================================================== %%
fprintf('\n--- Sample rate breakdown ---\n');
for k = 1:n_cases
    imp = zeros(N_imp,1); imp(1)=1;
    [~, ~, info_k] = tx_dpath(imp, Fs_in, cases(k).cfg);
    fprintf('\nCase %d: %s\n', k, cases(k).label);
    fprintf('  Input  : %8.3f MHz\n',  info_k.rate_in   /1e6);
    fprintf('  → TFIR : %8.3f MHz\n',  info_k.rate_tfir /1e6);
    fprintf('  → THB1 : %8.3f MHz\n',  info_k.rate_thb1 /1e6);
    if strcmp(info_k.path, 'THB')
        fprintf('  → THB2 : %8.3f MHz\n',  info_k.rate_thb2 /1e6);
        fprintf('  → THB3 : %8.3f MHz\n',  info_k.rate_thb3 /1e6);
    else
        fprintf('  → INT5 : %8.3f MHz\n',  info_k.rate_int5 /1e6);
    end
end

fprintf('\nTest complete.\n');

%% ---- Helper -------------------------------------------------------- %%
function s = conditional_str(cond, s_true, s_false)
    if cond, s = s_true; else, s = s_false; end
end
