function y = thb1_filter(x, bypass)
% THB1_FILTER  THB1 half-band interpolation filter (interpolation factor L = 2)
%
% Syntax:
%   y = thb1_filter(x)
%   y = thb1_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (column or row vector)
%   bypass - Logical flag (default: false)
%              false : upsample by 2 and apply THB1 FIR filter
%              true  : pass-through (output equals input, no rate change)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : length(y) = 2 * length(x)
%       bypass=true  : length(y) = length(x)  (same rate, no change)
%       (same orientation as x)
%
% Filter spec:
%   71-tap linear-phase symmetric half-band FIR; sum(h) = 2 for unity DC
%   passband gain after interpolation by 2.
%   THB1 coefficients as specified in the Tx digital path document.

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('thb1_filter: input x must be a 1-D vector.');
    end

    % ------------------------------------------------------------------ %
    %  THB1 FIR filter coefficients – 71 taps, symmetric half-band
    %  Odd-indexed taps (0-based) are all zero, as expected for a
    %  half-band filter.  sum(h) ≈ 2  → unity DC gain after L=2 interp.
    % ------------------------------------------------------------------ %
    h = [ ...
       -0.002319336,  0,  0.003601074,  0, -0.004058838,  0,  0.004119873,  0, ...
       -0.006439209,  0,  0.009613037,  0, -0.012023926,  0,  0.014404297,  0, ...
       -0.018737793,  0,  0.024291992,  0, -0.030059814,  0,  0.037353516,  0, ...
       -0.048156738,  0,  0.062927246,  0, -0.084350586,  0,  0.122283936,  0, ...
       -0.209564209,  0,  0.635925293,  1,  0.635925293,  0, -0.209564209,  0, ...
        0.122283936,  0, -0.084350586,  0,  0.062927246,  0, -0.048156738,  0, ...
        0.037353516,  0, -0.030059814,  0,  0.024291992,  0, -0.018737793,  0, ...
        0.014404297,  0, -0.012023926,  0,  0.009613037,  0, -0.006439209,  0, ...
        0.004119873,  0, -0.004058838,  0,  0.003601074,  0, -0.002319336];

    L           = 2;                        % Interpolation factor
    N_taps      = length(h);                % 71
    group_delay = (N_taps - 1) / 2;        % 35 output samples

    is_row = isrow(x);
    x      = x(:);          % column vector for upfirdn
    N_in   = length(x);
    N_out  = L * N_in;

    if bypass
        % ---- Bypass: pass input through unchanged ----------------------
        y = x;

    else
        % ---- Normal path: upsample by 2, apply FIR filter -------------
        % upfirdn produces length = N_in*L + N_taps - 1
        y_full = upfirdn(x, h, L, 1);

        % Remove group delay (35 output samples) for time alignment,
        % then keep exactly N_out = 2*N_in samples.
        y = y_full(group_delay + 1 : group_delay + N_out);
    end

    if is_row
        y = y.';
    end
end
