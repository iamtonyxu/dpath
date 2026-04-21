% test_thb_filters.m
% Tests and frequency response plots for THB3 and THB2 half-band filters.

clear; close all; clc;

%% ---- Coefficient summary ---------------------------------------------
h_thb3 = [0.125, 0.500, 0.750, 0.500, 0.125];
h_thb2 = [-0.08203125, 0, 0.58203125, 1, 0.58203125, 0, -0.08203125];

fprintf('--- THB3 ---\n');
fprintf('  Taps      : %d\n',   length(h_thb3));
fprintf('  sum(h)    : %.6f  (ideal = 2)\n', sum(h_thb3));
fprintf('  Symmetric : %d\n',   isequal(h_thb3, fliplr(h_thb3)));

fprintf('--- THB2 ---\n');
fprintf('  Taps      : %d\n',   length(h_thb2));
fprintf('  sum(h)    : %.6f  (ideal = 2)\n', sum(h_thb2));
fprintf('  Symmetric : %d\n',   isequal(h_thb2, fliplr(h_thb2)));

%% ---- Frequency responses (individual) --------------------------------
N_fft = 4096;

[H3, w3] = freqz(h_thb3, 1, N_fft, 'whole');
[H2, w2] = freqz(h_thb2, 1, N_fft, 'whole');

f_norm3 = w3/pi - 1;   % centred, -1…+1 (units of Fs_out/2)
f_norm2 = w2/pi - 1;

H3_db = 20*log10(abs(fftshift(H3)));
H2_db = 20*log10(abs(fftshift(H2)));

figure('Name','THB3 & THB2 – Individual Frequency Responses','NumberTitle','off');

subplot(2,2,1);
plot(f_norm3, H3_db, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('THB3 Magnitude Response  (5-tap half-band, L=2)');
xlim([-1 1]); ylim([-80 5]); grid on;
xline( 0.5, 'r--', 'Passband edge  1/L'); xline(-0.5, 'r--');

subplot(2,2,3);
plot(f_norm3, unwrap(angle(fftshift(H3)))*180/pi, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('THB3 Phase Response');
xlim([-1 1]); grid on;

subplot(2,2,2);
plot(f_norm2, H2_db, 'm', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('THB2 Magnitude Response  (7-tap half-band, L=2)');
xlim([-1 1]); ylim([-80 5]); grid on;
xline( 0.5, 'r--', 'Passband edge  1/L'); xline(-0.5, 'r--');

subplot(2,2,4);
plot(f_norm2, unwrap(angle(fftshift(H2)))*180/pi, 'm', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('THB2 Phase Response');
xlim([-1 1]); grid on;

%% ---- Cascaded response: THB3 → THB2 (each ×2, total ×4) -------------
% Express both filters at the common output rate (Fs_thb2_out = 4×Fs_in).
% THB3 output is at 2×Fs_in → upsample THB3 response to 4×Fs_in by
% inserting L=2 image, then multiply with THB2 response.
%
% Simpler equivalent: convolve the polyphase-equivalent prototype impulse
% responses at the final rate. We use the standard method:
%   H_cascade(z) = H_thb3(z^2) * H_thb2(z)  at Fs_out = 4*Fs_in
% i.e. stretch h_thb3 by 2 (insert zeros) then convolve with h_thb2.

h_thb3_upsampled = upsample(h_thb3, 2);   % 9 taps at 4x rate
h_cascade        = conv(h_thb3_upsampled, h_thb2);

[H_cas, w_cas] = freqz(h_cascade, 1, N_fft, 'whole');
f_norm_cas = w_cas/pi - 1;
H_cas_db   = 20*log10(abs(fftshift(H_cas)));

figure('Name','THB3+THB2 Cascaded Response','NumberTitle','off');

subplot(2,1,1);
hold on;
plot(f_norm3, H3_db,   'b--',  'LineWidth', 1.0, 'DisplayName', 'THB3 alone');
plot(f_norm2, H2_db,   'm--',  'LineWidth', 1.0, 'DisplayName', 'THB2 alone');
plot(f_norm_cas, H_cas_db, 'k', 'LineWidth', 1.4, 'DisplayName', 'THB3 → THB2 cascade');
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('Cascaded THB3 → THB2 Magnitude Response  (total L = 4)');
xlim([-1 1]); ylim([-80 5]); grid on; legend('Location','southwest');
xline( 0.25, 'r--', '1/(L_{total})'); xline(-0.25, 'r--');

subplot(2,1,2);
plot(f_norm_cas, unwrap(angle(fftshift(H_cas)))*180/pi, 'k', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('Cascaded THB3 → THB2 Phase Response');
xlim([-1 1]); grid on;

%% ---- Functional test: complex baseband sinewave ----------------------
Fs_in  = 1e6;
f_tone = 0.1e6;   % 100 kHz – within passband
N      = 256;

t_in = (0:N-1).' / Fs_in;
x_in = exp(1j * 2*pi * f_tone * t_in);

% Individual filter paths
y_thb3      = thb3_filter(x_in, false);
y_thb3_byp  = thb3_filter(x_in, true);
y_thb2      = thb2_filter(x_in, false);
y_thb2_byp  = thb2_filter(x_in, true);

% Cascade: THB3 → THB2 (total ×4)
y_cascade    = thb2_filter(thb3_filter(x_in, false), false);

fprintf('\n--- Output lengths ---\n');
fprintf('  THB3 normal  : %d  (expect %d)\n', length(y_thb3),  2*N);
fprintf('  THB3 bypass  : %d  (expect %d)\n', length(y_thb3_byp), N);
fprintf('  THB2 normal  : %d  (expect %d)\n', length(y_thb2),  2*N);
fprintf('  THB2 bypass  : %d  (expect %d)\n', length(y_thb2_byp), N);
fprintf('  Cascade x4   : %d  (expect %d)\n', length(y_cascade), 4*N);

%% ---- Spectrum of cascade output vs input -----------------------------
figure('Name','THB cascade – Spectrum','NumberTitle','off');

Fs_out4 = 4 * Fs_in;
win_in  = blackman(N);
win_out = blackman(length(y_cascade));

Y_in  = fftshift(fft(x_in      .* win_in));
Y_out = fftshift(fft(y_cascade .* win_out));

f_in  = (-N/2 : N/2-1)           * Fs_in  / N;
f_out = (-length(y_cascade)/2 : length(y_cascade)/2-1) * Fs_out4 / length(y_cascade);

subplot(2,1,1);
plot(f_in/1e6, 20*log10(abs(Y_in)/max(abs(Y_in))), 'b', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title(sprintf('Input Spectrum  (Fs = %.0f MHz)', Fs_in/1e6));
xlim([-Fs_in/2e6 Fs_in/2e6]); ylim([-80 5]); grid on;

subplot(2,1,2);
plot(f_out/1e6, 20*log10(abs(Y_out)/max(abs(Y_out))), 'k', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title(sprintf('THB3→THB2 Cascade Output Spectrum  (Fs = %.0f MHz)', Fs_out4/1e6));
xlim([-Fs_out4/2e6 Fs_out4/2e6]); ylim([-80 5]); grid on;

fprintf('\nTest complete.\n');
