% test_rx_dpath.m
% Test script for rx_dpath:
%   1) front path: DEC5 or FIR2/FIR1/RHB3
%   2) FIR-chain decimation options 2/4/8
%   3) HR/LP selection
%   4) PFIR programmable decimation and gain

clear; close all; clc;

%% -------------------- Global setup --------------------------------- %%
Fs_in = 245.76e6;  % Hz
N_in  = 8192;

rng(7);
x_raw = (randn(N_in,1) + 1j*randn(N_in,1)) / sqrt(2);

% Build a 200 MHz BW complex baseband test signal (±100 MHz)
BW_edge = 100e6;
h_bw = fir1(255, BW_edge/(Fs_in/2));
x_in = filter(h_bw, 1, x_raw);

% Example PFIR coefficient sets (must be 24/48/72 taps)
h_pfir_24 = fir1(23, 0.80);
h_pfir_48 = fir1(47, 0.80);
h_pfir_72 = fir1(71, 0.80);

%% -------------------- Test cases ----------------------------------- %%
cases = struct();

% Case 1: DEC5 front, HR, PFIR decim=1
cases(1).label = 'DEC5 -> RHB2 -> HR -> PFIR(dec1)';
cases(1).cfg.front_path  = 'DEC5';
cases(1).cfg.dec5_bypass = false;
cases(1).cfg.rhb2_bypass = false;
cases(1).cfg.rhb1_mode   = 'HR';
cases(1).cfg.hr_bypass   = false;
cases(1).cfg.pfir_bypass = false;
cases(1).cfg.pfir_h      = h_pfir_24;
cases(1).cfg.pfir_decim  = 1;
cases(1).cfg.pfir_gain_db = 0;

% Case 2: FIR-chain x2 (FIR2/FIR1 bypass, RHB3 active), LP, PFIR dec1
cases(2).label = 'FIR chain x2 -> RHB2 -> LP -> PFIR(dec1)';
cases(2).cfg.front_path   = 'FIR_CHAIN';
cases(2).cfg.fir2_bypass  = true;
cases(2).cfg.fir1_bypass  = true;
cases(2).cfg.rhb2_bypass  = false;
cases(2).cfg.rhb1_mode    = 'LP';
cases(2).cfg.lp_bypass    = false;
cases(2).cfg.pfir_bypass  = false;
cases(2).cfg.pfir_h       = h_pfir_48;
cases(2).cfg.pfir_decim   = 1;
cases(2).cfg.pfir_gain_db = 0;

% Case 3: FIR-chain x4 (FIR2 active, FIR1 bypass), HR, PFIR dec2
cases(3).label = 'FIR chain x4 -> RHB2 -> HR -> PFIR(dec2)';
cases(3).cfg.front_path   = 'FIR_CHAIN';
cases(3).cfg.fir2_bypass  = false;
cases(3).cfg.fir1_bypass  = true;
cases(3).cfg.rhb2_bypass  = false;
cases(3).cfg.rhb1_mode    = 'HR';
cases(3).cfg.hr_bypass    = false;
cases(3).cfg.pfir_bypass  = false;
cases(3).cfg.pfir_h       = h_pfir_48;
cases(3).cfg.pfir_decim   = 2;
cases(3).cfg.pfir_gain_db = -6;

% Case 4: FIR-chain x8 (FIR2+FIR1 active), LP, PFIR dec4
cases(4).label = 'FIR chain x8 -> RHB2 -> LP -> PFIR(dec4)';
cases(4).cfg.front_path   = 'FIR_CHAIN';
cases(4).cfg.fir2_bypass  = false;
cases(4).cfg.fir1_bypass  = false;
cases(4).cfg.rhb2_bypass  = false;
cases(4).cfg.rhb1_mode    = 'LP';
cases(4).cfg.lp_bypass    = false;
cases(4).cfg.pfir_bypass  = false;
cases(4).cfg.pfir_h       = h_pfir_72;
cases(4).cfg.pfir_decim   = 4;
cases(4).cfg.pfir_gain_db = 0;

% Case 5: DEC5 front, LP, PFIR bypass
cases(5).label = 'DEC5 -> RHB2 -> LP -> PFIR(bypass)';
cases(5).cfg.front_path   = 'DEC5';
cases(5).cfg.dec5_bypass  = false;
cases(5).cfg.rhb2_bypass  = false;
cases(5).cfg.rhb1_mode    = 'LP';
cases(5).cfg.lp_bypass    = false;
cases(5).cfg.pfir_bypass  = true;

%% -------------------- Run length/rate checks ----------------------- %%
fprintf('\n%-45s %-10s %-12s %-12s\n', 'Case', 'Decim', 'Fs_out(MHz)', 'Len(out)');
fprintf('%s\n', repmat('-', 1, 86));

for k = 1:numel(cases)
    [y, Fs_out, info] = rx_dpath(x_in, Fs_in, cases(k).cfg);
    fprintf('%-45s %-10.3f %-12.6f %-12d\n', ...
        cases(k).label, info.total_decim, Fs_out/1e6, length(y));
end

%% -------------------- Frequency-response plots ---------------------- %%
% Impulse-response method for equivalent cascade response.
N_imp = 4096;
imp = zeros(N_imp,1); imp(1) = 1;

figure('Name','RX DPath Frequency Responses','NumberTitle','off', ...
       'Position',[80 80 1200 800]);

for k = 1:numel(cases)
    [h_eq, Fs_out, info] = rx_dpath(imp, Fs_in, cases(k).cfg);

    N_fft = max(8192, 2^nextpow2(length(h_eq)*2));
    H = fft(h_eq, N_fft);
    H_db = 20*log10(abs(fftshift(H)) + eps);
    f_norm = linspace(-1, 1, N_fft);  % normalized to Fs_out/2

    subplot(3,2,k);
    plot(f_norm, H_db, 'LineWidth', 1.1);
    grid on;
    xlim([-1 1]);
    ylim([-250 10]);
    xlabel('Normalized frequency (x F_{s,out}/2)');
    ylabel('Magnitude (dB)');
    title(sprintf('Case %d: %s\nFs_{out}=%.3f MHz, Decim x%.3f', ...
          k, cases(k).label, Fs_out/1e6, info.total_decim), 'FontSize', 8);
end
sgtitle('RX Digital Path: Equivalent Frequency Responses', 'FontSize', 11);

%% -------------------- Spectrum in physical frequency ---------------- %%
% Show input/output single-sided spectra [0, Fs_out] for Case 1 and Case 4.
figure('Name','RX DPath Input/Output Spectrum [0, Fs_out]','NumberTitle','off');
show_cases = [1, 4];

for row = 1:2
    c = show_cases(row);
    [y, Fs_out, info] = rx_dpath(x_in, Fs_in, cases(c).cfg);

    N0 = length(x_in);
    N1 = length(y);

    Xin = fft(x_in .* blackman(N0));
    Yout = fft(y .* blackman(N1));

    f0 = (0:N0-1) * Fs_in / N0;
    f1 = (0:N1-1) * Fs_out / N1;

    Xin_db = 20*log10(abs(Xin)/max(abs(Xin)) + eps);
    Yout_db = 20*log10(abs(Yout)/max(abs(Yout)) + eps);

    subplot(2,2,(row-1)*2 + 1);
    plot(f0/1e6, Xin_db, 'b', 'LineWidth', 1.0);
    grid on; xlim([0 Fs_in/1e6]); ylim([-250 10]);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Input Spectrum [0, Fs_{in}]  (Fs_{in}=%.2f MHz)', Fs_in/1e6));

    subplot(2,2,(row-1)*2 + 2);
    plot(f1/1e6, Yout_db, 'r', 'LineWidth', 1.0);
    grid on; xlim([0 Fs_out/1e6]); ylim([-250 10]);
    xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, norm.)');
    title(sprintf('Case %d Output [0, Fs_{out}]  (Fs_{out}=%.2f MHz, x%.3f)', ...
          c, Fs_out/1e6, info.total_decim));
end
sgtitle('RX DPath Input/Output Spectra (single-sided)', 'FontSize', 11);

fprintf('\nTest complete.\n');
