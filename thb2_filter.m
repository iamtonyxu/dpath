function y = thb2_filter(x, bypass)
% THB2_FILTER  THB2 half-band interpolation filter (interpolation factor L = 2)
%
% Syntax:
%   y = thb2_filter(x)
%   y = thb2_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (column or row vector)
%   bypass - Logical flag (default: false)
%              false : upsample by 2 and apply THB2 FIR filter
%              true  : pass-through (output equals input, no rate change)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : length(y) = 2 * length(x)
%       bypass=true  : length(y) = length(x)  (same rate, no change)
%       (same orientation as x)
%
% Filter spec:
%   7-tap linear-phase symmetric half-band FIR; sum(h) = 2 for unity DC
%   passband gain after interpolation by 2.
%   THB2 coefficients: -0.08203125, 0, 0.58203125, 1, 0.58203125, 0, -0.08203125

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('thb2_filter: input x must be a 1-D vector.');
    end

    % ------------------------------------------------------------------ %
    %  THB2 FIR filter coefficients – 7 taps, symmetric half-band
    %  sum(h) = 2  →  unity DC gain after L=2 interpolation
    % ------------------------------------------------------------------ %
    h = [-0.08203125, 0, 0.58203125, 1, 0.58203125, 0, -0.08203125];

    L           = 2;                        % Interpolation factor
    N_taps      = length(h);                % 7
    group_delay = (N_taps - 1) / 2;        % 3 output samples

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

        % Remove group delay (3 output samples) for time alignment,
        % then keep exactly N_out = 2*N_in samples.
        y = y_full(group_delay + 1 : group_delay + N_out);
    end

    if is_row
        y = y.';
    end
end
