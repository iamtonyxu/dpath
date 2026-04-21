% test_int5_filter.m
% Verifies INT5 filter functionality and plots frequency response.

clear; close all; clc;

%% ---- Coefficient verification ----------------------------------------
h = [ ...
    0.002929688,  0.029052734, -0.029296875,  0.031250000, -0.012207031, ...
   -0.005859375, -0.056640625,  0.051513672, -0.055664063,  0.025390625, ...
    0.020996094,  0.081298828, -0.057617188,  0.072509766, -0.045166016, ...
   -0.047607422, -0.095947266,  0.030517578, -0.071289063,  0.068603516, ...
    0.093994141,  0.113769531,  0.030761719,  0.055419922, -0.103759766, ...
   -0.185791016, -0.185302734, -0.136962891, -0.037353516,  0.227050781, ...
    0.518554688,  0.717285156,  0.928466797,  1.019287109,  0.928466797, ...
    0.717285156,  0.518554688,  0.227050781, -0.037353516, -0.136962891, ...
   -0.185302734, -0.185791016, -0.103759766,  0.055419922,  0.030761719, ...
    0.113769531,  0.093994141,  0.068603516, -0.071289063,  0.030517578, ...
   -0.095947266, -0.047607422, -0.045166016,  0.072509766, -0.057617188, ...
    0.081298828,  0.020996094,  0.025390625, -0.055664063,  0.051513672, ...
   -0.056640625, -0.005859375, -0.012207031,  0.031250000, -0.029296875, ...
    0.029052734,  0.002929688];

fprintf('Number of taps : %d\n',   length(h));
fprintf('sum(h)         : %.6f  (ideal = 5)\n', sum(h));
fprintf('Symmetric      : %d\n',   isequal(h, fliplr(h)));

%% ---- Frequency response of the filter itself --------------------------
L     = 5;
N_fft = 4096;

% h is defined at the output (high) sample rate.
% Normalised frequency w=0…pi corresponds to 0…Fs_out/2.
[H, w] = freqz(h, 1, N_fft, 'whole');

% Convert to double-sided spectrum centred at 0
f_norm = (w / pi - 1);          % -1 … +1  (in units of Fs_out/2)
H_db   = 20*log10(abs(fftshift(H)));

figure('Name','INT5 Filter – Frequency Response','NumberTitle','off');

subplot(2,1,1);
plot(f_norm, H_db, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Magnitude (dB)');
title('INT5 Filter Magnitude Response  (67-tap FIR, L = 5)');
xlim([-1 1]); ylim([-80 5]);
grid on;
% Mark the passband edge at 1/L = 0.2 (relative to Fs_out/2)
xline( 1/L, 'r--', 'Passband edge  1/L');
xline(-1/L, 'r--');

subplot(2,1,2);
phase_rad = angle(fftshift(H));
plot(f_norm, unwrap(phase_rad) * 180/pi, 'b', 'LineWidth', 1.2);
xlabel('Normalised frequency  (× F_{s,out}/2)');
ylabel('Phase (degrees)');
title('INT5 Filter Phase Response');
xlim([-1 1]); grid on;

%% ---- Functional test: complex baseband sinewave -----------------------
Fs_in   = 1e6;              % Input sample rate  (arbitrary)
Fs_out  = L * Fs_in;        % Output sample rate after INT5
f_tone  = 0.1e6;            % 100 kHz tone  (within passband after interp)
N       = 256;              % Number of input samples

t_in    = (0:N-1).' / Fs_in;
x_in    = exp(1j * 2*pi * f_tone * t_in);   % complex baseband input

% -- Normal path --
y_norm  = int5_filter(x_in, false);

% -- Bypass path --
y_byp   = int5_filter(x_in, true);

t_out   = (0:length(y_norm)-1).' / Fs_out;

figure('Name','INT5 – Time-domain comparison','NumberTitle','off');
subplot(2,1,1);
plot(t_out*1e6, real(y_norm));
xlabel('Time (µs)'); ylabel('Re\{y\}');
title(sprintf('INT5 Output – Normal path  (f_{tone} = %.0f kHz)', f_tone/1e3));
grid on;

subplot(2,1,2);
plot(t_out*1e6, real(y_byp));
xlabel('Time (µs)'); ylabel('Re\{y\}');
title('INT5 Output – Bypass path (zero-stuffed only)');
grid on;

%% ---- Spectrum check ---------------------------------------------------
figure('Name','INT5 – Output spectrum','NumberTitle','off');

win     = blackman(length(y_norm));
Y_norm  = fftshift(fft(y_norm .* win));
Y_byp   = fftshift(fft(y_byp .* win));
f_axis  = (-length(y_norm)/2 : length(y_norm)/2-1) * Fs_out / length(y_norm);

subplot(2,1,1);
plot(f_axis/1e6, 20*log10(abs(Y_norm)/max(abs(Y_norm))), 'b', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title('INT5 Output Spectrum – Normal path');
xlim([-Fs_out/2e6  Fs_out/2e6]); ylim([-80 5]); grid on;

subplot(2,1,2);
plot(f_axis/1e6, 20*log10(abs(Y_byp)/max(abs(Y_byp))), 'r', 'LineWidth', 1.0);
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB, normalised)');
title('INT5 Output Spectrum – Bypass path (images NOT removed)');
xlim([-Fs_out/2e6  Fs_out/2e6]); ylim([-80 5]); grid on;

fprintf('\nTest complete.  Output lengths:  normal=%d,  bypass=%d  (expect %d)\n', ...
        length(y_norm), length(y_byp), L*N);
