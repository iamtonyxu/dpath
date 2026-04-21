function y = LP_filter(x, bypass)
% LP_FILTER  Receive Half Band Low Power 1 (RHB1-LP)
%
% Syntax:
%   y = LP_filter(x)
%   y = LP_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (row or column vector)
%   bypass - Logical flag (default: false)
%              false : apply LP filter and decimate by 2
%              true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : approximately length(x)/2
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% RHB1 (LP) coefficients (fixed):
%   [-0.002685547, 0, 0.017333984, 0, -0.068359375, 0, 0.304443359,
%    0.501708984, 0.304443359, 0, -0.068359375, 0, 0.017333984,
%    0, -0.002685547]

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('LP_filter: input x must be a 1-D vector.');
    end

    h = [ ...
        -0.002685547, 0, 0.017333984, 0, -0.068359375, 0, 0.304443359, ...
         0.501708984, 0.304443359, 0, -0.068359375, 0, 0.017333984, 0, ...
        -0.002685547];

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
