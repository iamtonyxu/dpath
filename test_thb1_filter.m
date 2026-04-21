% test_thb1_filter.m
% Tests and frequency response plots for the THB1 half-band filter,
% plus a comparison across all three THB stages (THB1, THB2, THB3).

clear; close all; clc;

%% ---- Coefficient summary ---------------------------------------------
h_thb1 = [ ...
   -0.002319336,  0,  0.003601074,  0, -0.004058838,  0,  0.004119873,  0, ...
   -0.006439209,  0,  0.009613037,  0, -0.012023926,  0,  0.014404297,  0, ...
   -0.018737793,  0,  0.024291992,  0, -0.030059814,  0,  0.037353516,  0, ...
   -0.048156738,  0,  0.062927246,  0, -0.084350586,  0,  0.122283936,  0, ...
   -0.209564209,  0,  0.635925293,  1,  0.635925293,  0, -0.209564209,  0, ...
    0.122283936,  0, -0.084350586,  0,  0.062927246,  0, -0.048156738,  0, ...
    0.037353516,  0, -0.030059814,  0,  0.024291992,  0, -0.018737793,  0, ...
    0.014404297,  0, -0.012023926,  0,  0.009613037,  0, -0.006439209,  0, ...
    0.004119873,  0, -0.004058838,  0,  0.003601074,  0, -0.002319336];

h_thb2 = [-0.08203125, 0, 0.58203125, 1, 0.58203125, 0, -0.08203125];
h_thb3 = [0.125, 0.500, 0.750, 0.500, 0.125];

fprintf('--- THB1 ---\n');
fprintf('  Taps      : %d\n',   length(h_thb1));
fprintf('  sum(h)    : %.6f  (ideal = 2)\n', sum(h_thb1));
fprintf('  Symmetric : %d\n',   isequal(h_thb1, fliplr(h_thb1)));

%% ---- THB1 individual frequency response ------------------------------
N_fft = 8192;

[H1, w1] = freqz(h_thb1, 1, N_fft, 'whole');
f_norm1  = w1/pi - 1;   % centred, -1…+1  (units of Fs_out/2)
H1_db    = 20*log10(abs(fftshift(H1)));

figure('Name','THB1 – Frequency Response','NumberTitle','off');

subplot(2,1,1);
plot(f_norm1, H1_db, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('THB1 Magnitude Response  (71-tap half-band, L=2)');
xlim([-1 1]); ylim([-120 5]); grid on;
xline( 0.5, 'r--', 'Passband edge  1/L');
xline(-0.5, 'r--');

subplot(2,1,2);
plot(f_norm1, unwrap(angle(fftshift(H1)))*180/pi, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('THB1 Phase Response');
xlim([-1 1]); grid on;

%% ---- Comparison: THB1 vs THB2 vs THB3 --------------------------------
[H2, w2] = freqz(h_thb2, 1, N_fft, 'whole');
[H3, w3] = freqz(h_thb3, 1, N_fft, 'whole');

f_norm = w1/pi - 1;   % all same length
H1_db  = 20*log10(abs(fftshift(H1)));
H2_db  = 20*log10(abs(fftshift(H2)));
H3_db  = 20*log10(abs(fftshift(H3)));

figure('Name','THB1 vs THB2 vs THB3 – Magnitude Comparison','NumberTitle','off');
plot(f_norm, H1_db, 'b',  'LineWidth', 1.2, 'DisplayName', 'THB1 (71-tap)'); hold on;
plot(f_norm, H2_db, 'm',  'LineWidth', 1.2, 'DisplayName', 'THB2  (7-tap)');
plot(f_norm, H3_db, 'g',  'LineWidth', 1.2, 'DisplayName', 'THB3  (5-tap)');
xline( 0.5, 'r--', 'Passband edge  1/L'); xline(-0.5, 'r--');
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('Magnitude Response Comparison: THB1 / THB2 / THB3');
xlim([-1 1]); ylim([-120 5]); grid on;
legend('Location','southwest');

%% ---- Cascaded response: THB1 → THB2 → THB3 (total ×8) ---------------
% Build equivalent prototype at the final output rate (8× input rate).
%   H_cas(z) = H_thb1(z^4) * H_thb2(z^2) * H_thb3(z)
% i.e. stretch each filter to the final rate then convolve.

h_thb1_x4 = upsample(h_thb1, 4);   % at 8x rate
h_thb2_x2 = upsample(h_thb2, 2);   % at 8x rate (thb2 runs at 2x input)
h_cascade  = conv(conv(h_thb1_x4, h_thb2_x2), h_thb3);

[H_cas, w_cas] = freqz(h_cascade, 1, N_fft, 'whole');
f_norm_cas = w_cas/pi - 1;
H_cas_db   = 20*log10(abs(fftshift(H_cas)));

figure('Name','THB1→THB2→THB3 Cascaded Response','NumberTitle','off');

subplot(2,1,1);
plot(f_norm_cas, H_cas_db, 'k', 'LineWidth', 1.4);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('Cascaded THB1→THB2→THB3 Magnitude Response  (total L = 8)');
xlim([-1 1]); ylim([-120 5]); grid on;
xline( 1/8, 'r--', '1/L_{total}'); xline(-1/8, 'r--');

subplot(2,1,2);
plot(f_norm_cas, unwrap(angle(fftshift(H_cas)))*180/pi, 'k', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('Cascaded THB1→THB2→THB3 Phase Response');
xlim([-1 1]); grid on;

%% ---- Functional test: complex baseband sinewave ----------------------
Fs_in  = 1e6;
f_tone = 0.05e6;   % 50 kHz – well within passband
N      = 512;

t_in = (0:N-1).' / Fs_in;
x_in = exp(1j * 2*pi * f_tone * t_in);

% Individual paths
y_thb1     = thb1_filter(x_in, false);
y_thb1_byp = thb1_filter(x_in, true);

% Full cascade: THB1 → THB2 → THB3 (total ×8)
y_full_cascade = thb3_filter(thb2_filter(thb1_filter(x_in, false), false), false);

fprintf('\n--- Output lengths ---\n');
fprintf('  THB1 normal     : %d  (expect %d)\n', length(y_thb1),     2*N);
fprintf('  THB1 bypass     : %d  (expect %d)\n', length(y_thb1_byp), N);
fprintf('  THB1+THB2+THB3  : %d  (expect %d)\n', length(y_full_cascade), 8*N);

%% ---- Input vs full cascade output spectrum ---------------------------
figure('Name','THB1+THB2+THB3 – Spectrum','NumberTitle','off');

Fs_out8 = 8 * Fs_in;
Y_in    = fftshift(fft(x_in            .* blackman(N)));
Y_out   = fftshift(fft(y_full_cascade  .* blackman(length(y_full_cascade))));

f_in  = (-N/2              : N/2-1)              * Fs_in  / N;
f_out = (-length(y_full_cascade)/2 : length(y_full_cascade)/2-1) * Fs_out8 / length(y_full_cascade);

subplot(2,1,1);
plot(f_in/1e6, 20*log10(abs(Y_in)/max(abs(Y_in))), 'b', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title(sprintf('Input Spectrum  (Fs = %.0f MHz)', Fs_in/1e6));
xlim([-Fs_in/2e6  Fs_in/2e6]); ylim([-120 5]); grid on;

subplot(2,1,2);
plot(f_out/1e6, 20*log10(abs(Y_out)/max(abs(Y_out))), 'k', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title(sprintf('THB1→THB2→THB3 Output Spectrum  (Fs = %.0f MHz)', Fs_out8/1e6));
xlim([-Fs_out8/2e6  Fs_out8/2e6]); ylim([-120 5]); grid on;

fprintf('\nTest complete.\n');
