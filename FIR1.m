function y = FIR1(x, bypass)
% FIR1  Fixed-coefficient decimation filter (decimate-by-2)
%
% Syntax:
%   y = FIR1(x)
%   y = FIR1(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (row or column vector)
%   bypass - Logical flag (default: false)
%              false : apply FIR1 then decimate by 2
%              true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : approximately length(x)/2
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% FIR1 coefficients (fixed):
%   [0.0625, 0.25, 0.375, 0.25, 0.0625]

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('FIR1: input x must be a 1-D vector.');
    end

    h = [0.0625, 0.25, 0.375, 0.25, 0.0625];
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
