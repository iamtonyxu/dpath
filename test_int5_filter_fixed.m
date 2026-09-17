% test_int5_filter_fixed.m
% Compares the fixed-point int5_filter_fixed against the floating-point
% int5_filter under identical stimuli, and quantifies the fixed-point error
% (max/RMS error, SNR, ENOB) as a function of the parameterised word widths.
%
% NOTE on input scaling: the fixed-point data path is Q1.FRAC_W (range
% +-2 for the default 16-bit / 14-fractional format).  Stimuli are scaled so
% their peak stays within +-1 so the unity-gain INT5 passband does not wrap.

clear; close all; clc;

%% ---- Test setup -------------------------------------------------------
L       = 5;
Fs_in   = 1e6;              % input sample rate (arbitrary)
Fs_out  = L * Fs_in;        % output sample rate after INT5
N       = 512;              % number of input samples

%% ---- Stimulus 1: complex tone (matches test_int5_filter) --------------
f_tone  = 0.1e6;            % 100 kHz, well inside the INT5 passband
t_in    = (0:N-1).' / Fs_in;
x_tone  = exp(1j * 2*pi * f_tone * t_in);

%% ---- Stimulus 2: band-limited complex noise ---------------------------
% Exercises the full passband rather than a single spectral line.
rng(0);
x_noise = lowpass_complex_noise(N, 0.8 * Fs_in/2, Fs_in);

run_comparison('complex tone',       x_tone,  Fs_out);
run_comparison('band-limited noise', x_noise, Fs_out);

%% ---- Rounding-mode comparison -----------------------------------------
fprintf('\n--- Rounding mode vs error (tone, DATA_W=16, FRAC_W=14) ---\n');
opts_floor = struct('DATA_W',16,'COEFF_W',16,'FRAC_W',14,'rounding','floor');
opts_round = struct('DATA_W',16,'COEFF_W',16,'FRAC_W',14,'rounding','round');
yf = int5_filter(x_tone, false);
snr1 = snr_db(yf, int5_filter_fixed(x_tone, false, opts_floor));
snr2 = snr_db(yf, int5_filter_fixed(x_tone, false, opts_round));
fprintf('  floor (truncate): SNR = %7.2f dB\n', snr1);
fprintf('  round            : SNR = %7.2f dB\n', snr2);

%% ---- Word-width sweep: SNR vs fractional bits -------------------------
% Isolate the coefficient/input/output quantization: give the accumulator
% full 64-bit precision so the sweep reflects word width, not ACC overflow.
fprintf('\n--- Word-width sweep (DATA_W = COEFF_W = FRAC_W + 2) ---\n');
frac_list = 6:18;
snr_floor = zeros(size(frac_list));
snr_round = zeros(size(frac_list));
for i = 1:numel(frac_list)
    fw = frac_list(i);
    o1 = struct('DATA_W',fw+2,'COEFF_W',fw+2,'FRAC_W',fw,'ACC_W',64,'rounding','floor');
    o2 = struct('DATA_W',fw+2,'COEFF_W',fw+2,'FRAC_W',fw,'ACC_W',64,'rounding','round');
    snr_floor(i) = snr_db(yf, int5_filter_fixed(x_tone, false, o1));
    snr_round(i) = snr_db(yf, int5_filter_fixed(x_tone, false, o2));
    fprintf('  FRAC_W=%2d  ->  floor SNR=%7.2f dB   round SNR=%7.2f dB\n', ...
        fw, snr_floor(i), snr_round(i));
end

figure('Name','INT5 fixed – SNR vs word width','NumberTitle','off');
plot(frac_list, snr_floor, 'o-', frac_list, snr_round, 's-', 'LineWidth', 1.2);
xline(14, 'k--', 'default FRAC_W');
xlabel('Fractional bits FRAC_W   (DATA_W = COEFF_W = FRAC_W + 2)');
ylabel('Fixed-point SNR (dB)');
title('INT5 fixed-point error vs word width');
legend('floor (truncate)', 'round', 'Location','southeast');
grid on;

fprintf('\nAll INT5 fixed-point comparisons complete.\n');

% ---------------------------------------------------------------------- %
function run_comparison(name, x, Fs_out)
% RUN_COMPARISON  Apply both filters to the same input and report error.

    yf = int5_filter(x, false);                     % floating-point reference
    yq = int5_filter_fixed(x, false);               % fixed-point (defaults)

    assert(isequal(size(yf), size(yq)), ...
        '%s: output size mismatch  float=%s  fixed=%s', ...
        name, mat2str(size(yf)), mat2str(size(yq)));

    err      = yq - yf;                             % complex error
    max_abs  = max(abs(err));
    rms_err  = sqrt(mean(abs(err).^2));
    snr      = snr_db(yf, yq);

    fprintf('\n=== %s ===\n', name);
    fprintf('  length           : %d (float) == %d (fixed)\n', length(yf), length(yq));
    fprintf('  max |error|      : %10.4g\n', max_abs);
    fprintf('  RMS error        : %10.4g\n', rms_err);
    fprintf('  SNR              : %7.2f dB\n', snr);
    fprintf('  ENOB             : %7.2f bits\n', (snr - 1.76) / 6.02);

    % ---- plots --------------------------------------------------------
    t_out = (0:length(yf)-1).' / Fs_out;

    figure('Name', sprintf('INT5 fixed vs float – %s', name), 'NumberTitle','off');
    subplot(2,1,1);
    plot(t_out*1e6, real(yf), 'b', t_out*1e6, real(yq), 'r--', 'LineWidth', 1.1);
    xlabel('Time (\mus)'); ylabel('Re\{y\}');
    title(sprintf('Float vs fixed output  (%s)', name));
    legend('float','fixed'); grid on;

    subplot(2,1,2);
    plot(t_out*1e6, abs(err), 'k', 'LineWidth', 1.0);
    xlabel('Time (\mus)'); ylabel('|error|');
    title('Fixed-point error magnitude'); grid on;
end

% ---------------------------------------------------------------------- %
function s = snr_db(ref, est)
% SNR_DB  Signal-to-quantization-error ratio in dB.
    sig = mean(abs(ref).^2);
    err = mean(abs(est - ref).^2);
    s   = 10 * log10(sig / err);
end

% ---------------------------------------------------------------------- %
function x = lowpass_complex_noise(N, bw, Fs)
% LOWPASS_COMPLEX_NOISE  Complex baseband noise, |f| < bw, peak <= 0.5.
    n = 8 * N;
    w = randn(n, 1) + 1j * randn(n, 1);
    b = fir1(64, bw / (Fs/2));          % normalized cutoff
    v = filter(b, 1, w);
    v = v(65 + (1:N));                  % skip the FIR transient
    v = v / (2 * max(abs(v)));          % peak ~0.5, safe for Q14 range +-2
    x = v(:);
end
