function y = int5_filter(x, bypass)
% INT5_FILTER  INT5 interpolation filter (interpolation factor L = 5)
%
% Syntax:
%   y = int5_filter(x)
%   y = int5_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (column or row vector)
%   bypass - Logical flag (default: false)
%              false : upsample by 5 and apply INT5 FIR filter
%              true  : upsample by 5 (zero-stuffing only, no filtering)
%
% Output:
%   y - Complex baseband output signal; length(y) = 5 * length(x)
%       (same orientation as x)
%
% Filter spec:
%   67-tap linear-phase symmetric FIR; sum(h) ≈ 5 for unity DC passband
%   gain. Coefficients sourced directly from the Tx digital path spec.

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('int5_filter: input x must be a 1-D vector.');
    end

    % ------------------------------------------------------------------ %
    %  INT5 FIR filter coefficients – 67 taps, symmetric
    %  Note: position 65 typo "-−" in spec corrected to "-" per symmetry
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

    L            = 5;       % Interpolation factor
    N_taps       = length(h);                  % 67
    group_delay  = (N_taps - 1) / 2;          % 33 output samples

    is_row = isrow(x);
    x      = x(:);          % column vector for upfirdn
    N_in   = length(x);
    N_out  = L * N_in;

    if bypass
        % ---- Bypass: zero-stuffing only, no convolution ----------------
        y = upsample(x, L);    % length = N_out

    else
        % ---- Normal path: upsample by L, apply FIR filter --------------
        % upfirdn produces length = N_in*L + N_taps - 1
        y_full = upfirdn(x, h, L, 1);

        % Remove the linear-phase group delay (33 output samples) so the
        % filtered output is time-aligned with the input, then keep exactly
        % N_out = 5*N_in samples.
        y = y_full(group_delay + 1 : group_delay + N_out);
    end

    if is_row
        y = y.';
    end
end
