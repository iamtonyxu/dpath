function y = int5_filter_fixed(x, bypass, opts)
% INT5_FILTER_FIXED  Fixed-point INT5 interpolation filter (L = 5)
%
%   Fixed-point replacement for int5_filter with an identical I/O contract:
%   same output length (5 * length(x)), same group-delay alignment, same
%   bypass semantics, same input/output orientation.  Only the internal
%   arithmetic changes: all signals and coefficients are quantized to the
%   parameterised fixed-point formats below.
%
%   Syntax:
%     y = int5_filter_fixed(x)
%     y = int5_filter_fixed(x, bypass)
%     y = int5_filter_fixed(x, bypass, opts)
%
%   Inputs:
%     x      - Complex baseband input (column or row vector), double.
%     bypass - Logical flag (default: false); same meaning as int5_filter.
%     opts   - Optional struct of quantization parameters:
%                .DATA_W    data word width           (default 16)
%                .COEFF_W   coefficient word width    (default 16)
%                .FRAC_W    fractional bits (Q format)(default 14)
%                .ACC_W     accumulator width         (default 40)
%                .rounding  output rounding mode      (default 'floor')
%                             'floor' : truncate (matches hardware >>>)
%                             'round' : round-to-nearest
%                             'ceil' / 'fix'
%
%   Output:
%     y - Complex baseband output, double; length(y) = 5 * length(x).
%
%   Quantization model (two's-complement, full-precision MAC):
%     1. Coefficients h are quantized to a COEFF_W-bit signed word with
%        FRAC_W fractional bits.  The INT5 coefficients are already exact
%        multiples of 2^-14, so with the default FRAC_W = 14 this step is
%        lossless (the fractional bits are captured exactly).
%     2. Input x is quantized to a DATA_W-bit signed word with FRAC_W
%        fractional bits (range ±2^(DATA_W-FRAC_W-1)).
%     3. The MAC is accumulated in ACC_W-bit full precision.
%     4. Each output sample is scaled by 2^-FRAC_W with the selected
%        rounding mode and wrapped to a DATA_W-bit signed word.

    if nargin < 2 || isempty(bypass), bypass = false; end
    if nargin < 3, opts = struct(); end

    DATA_W   = get_opt(opts, 'DATA_W',   16);
    COEFF_W  = get_opt(opts, 'COEFF_W',  16);
    FRAC_W   = get_opt(opts, 'FRAC_W',   14);
    ACC_W    = get_opt(opts, 'ACC_W',    40);
    rounding = get_opt(opts, 'rounding', 'floor');

    if ~isvector(x)
        error('int5_filter_fixed: input x must be a 1-D vector.');
    end

    % ------------------------------------------------------------------ %
    %  INT5 FIR filter coefficients – 67 taps, symmetric
    %  (identical to int5_filter.m; already exact multiples of 2^-14)
    % ------------------------------------------------------------------ %
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

    L            = 5;                        % interpolation factor
    N_taps       = length(h);                % 67
    group_delay  = (N_taps - 1) / 2;        % 33 output samples

    is_row = isrow(x);
    x      = x(:);
    N_in   = length(x);
    N_out  = L * N_in;

    % Quantize coefficients (real) and the I/Q parts of the input to their
    % fixed-point words (int64).  Real and imaginary paths are independent
    % signed words, mirroring the separate in_i / in_q lanes of the RTL.
    hq    = q2int(h,           COEFF_W, FRAC_W, rounding);
    xq_re = q2int(real(x),     DATA_W,  FRAC_W, rounding);
    xq_im = q2int(imag(x),     DATA_W,  FRAC_W, rounding);

    if bypass
        % ---- Bypass: zero-stuffing only (quantized input) --------------
        yq_re = zeros(N_out, 1, 'int64');   yq_re(1:L:N_out) = xq_re;
        yq_im = zeros(N_out, 1, 'int64');   yq_im(1:L:N_out) = xq_im;

    else
        % ---- Normal path: upsample by L, FIR filter, trim group delay --
        yf_re = fir_fixed(xq_re, hq, L, FRAC_W, DATA_W, ACC_W, rounding);
        yf_im = fir_fixed(xq_im, hq, L, FRAC_W, DATA_W, ACC_W, rounding);

        % Align with the input (remove the 33-sample linear-phase group
        % delay) and keep exactly N_out = 5*N_in samples, matching
        % int5_filter.m.
        yq_re = yf_re(group_delay + 1 : group_delay + N_out);
        yq_im = yf_im(group_delay + 1 : group_delay + N_out);
    end

    % Convert integer words back to physical values and recombine I/Q.
    y = (double(yq_re) + 1j * double(yq_im)) / 2^FRAC_W;

    if is_row
        y = y.';
    end
end

% ---------------------------------------------------------------------- %
function y = fir_fixed(xq, hq, L, FRAC_W, DATA_W, ACC_W, rounding)
% FIR_FIXED  Upsample xq by L and convolve with hq in fixed-point.
%
%   Returns the full convolution of length L*numel(xq) + numel(hq) - 1,
%   as DATA_W-bit signed integer words (the Q-word representation).
%   The accumulator is full precision (ACC_W bits); each output sample is
%   scaled by 2^-FRAC_W with the chosen rounding and wrapped to DATA_W bits.

    N_in   = length(xq);
    N_taps = length(hq);

    xup = zeros(L * N_in, 1, 'int64');
    xup(1:L:end) = xq;                    % zero-stuffing

    N_out = L * N_in + N_taps - 1;
    y = zeros(N_out, 1, 'int64');

    for i = 1:N_out
        k_lo = max(1, i - N_taps + 1);
        k_hi = min(i, L * N_in);
        acc  = int64(0);
        for k = k_lo:k_hi
            acc = acc + hq(i - k + 1) * xup(k);
        end
        % Model a finite ACC_W-bit accumulator (no-op when not overflowing).
        acc = wrap_signed(acc, ACC_W);
        % Quantize the output to a DATA_W-bit word.
        y(i) = int2q(acc, FRAC_W, DATA_W, rounding);
    end
end

% ---------------------------------------------------------------------- %
function w = q2int(v, W, FRAC_W, rounding)
% Q2INT  Quantize double v to a signed W-bit word with FRAC_W fractional
% bits; returns the stored integer word (int64), wrapping out-of-range
% values (two's complement).
    w = wrap_signed(round_mode(double(v) * 2^FRAC_W, rounding), W);
end

function v = int2q(acc, FRAC_W, W, rounding)
% INT2Q  Scale an integer accumulator by 2^-FRAC_W with the given rounding
% and wrap to a signed W-bit word (int64).
    v = wrap_signed(round_mode(double(acc) / 2^FRAC_W, rounding), W);
end

function r = round_mode(v, rounding)
% ROUND_MODE  Apply the selected rounding to v.
    switch rounding
        case 'round'
            r = round(v);
        case 'floor'
            r = floor(v);
        case 'ceil'
            r = ceil(v);
        case 'fix'
            r = fix(v);
        otherwise
            error('int5_filter_fixed: unknown rounding mode "%s".', rounding);
    end
end

function w = wrap_signed(v, W)
% WRAP_SIGNED  Wrap v to signed W-bit two's complement (int64).
%   For W >= 63 the int64 accumulator already provides a full 64-bit signed
%   range, so the value is passed through unchanged.
    if W >= 63
        w = int64(v);
        return;
    end
    M    = int64(2)^W;          % 2^W, exact in int64 for W <= 62
    half = M / 2;               % 2^(W-1)
    v    = int64(v);
    v    = mod(v, M);           % int64 reduction to [0, M)
    v(v >= half) = v(v >= half) - M;
    w    = int64(v);
end

function v = get_opt(opts, name, default)
% GET_OPT  Return opts.name if present and non-empty, else default.
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
    else
        v = default;
    end
end
