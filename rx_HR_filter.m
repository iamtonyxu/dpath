function y = rx_HR_filter(x, bypass)
% HR_FILTER  Receive Half Band High Rejection 1 (RHB1-HR)
%
% Syntax:
%   y = HR_filter(x)
%   y = HR_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (row or column vector)
%   bypass - Logical flag (default: false)
%              false : apply HR filter and decimate by 2
%              true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : approximately length(x)/2
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% RHB1 (HR) coefficients (fixed):
%   61 taps, symmetric half-band-like response.

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('rx_HR_filter: input x must be a 1-D vector.');
    end

    h = [ ...
         0.000106812, 0, -0.000289917, 0,  0.000625610, 0, -0.001205444, 0, ...
         0.002120972, 0, -0.003494263, 0,  0.005493164, 0, -0.008300781, 0, ...
         0.012207031, 0, -0.017639160, 0,  0.025421143, 0, -0.037170410, 0, ...
         0.057250977, 0, -0.101608276, 0,  0.314498901, 0.495956421, 0.314498901, 0, ...
        -0.101608276, 0,  0.057250977, 0, -0.037170410, 0,  0.025421143, 0, ...
        -0.017639160, 0,  0.012207031, 0, -0.008300781, 0,  0.005493164, 0, ...
        -0.003494263, 0,  0.002120972, 0, -0.001205444, 0,  0.000625610, 0, ...
        -0.000289917, 0,  0.000106812];

    M = 2;

    is_row = isrow(x);
    x = x(:);

    if bypass
        y = x;
    else
        % FIR filtering followed by decimation by 2.
        y = upfirdn(x, h, 1, M);
    end

    if is_row
        y = y.';
    end
end
