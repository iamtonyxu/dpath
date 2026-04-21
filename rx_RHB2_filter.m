function y = rx_RHB2_filter(x, bypass)
% RHB2_FILTER  Receive Half Band 2 fixed-coefficient decimation filter
%
% Syntax:
%   y = RHB2_filter(x)
%   y = RHB2_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (row or column vector)
%   bypass - Logical flag (default: false)
%              false : apply RHB2 filter and decimate by 2
%              true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : approximately length(x)/2
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% RHB2 coefficients (fixed):
%   [-0.000244141, 0, 0.001708984, 0, -0.0078125, 0, 0.026855469, 0, ...
%    -0.078369141, 0, 0.30859375, 0.501220703, 0.30859375, 0, ...
%    -0.078369141, 0, 0.026855469, 0, -0.0078125, 0, 0.001708984, ...
%    0, -0.000244141]

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('rx_RHB2_filter: input x must be a 1-D vector.');
    end

    h = [ ...
        -0.000244141, 0,  0.001708984, 0, -0.007812500, 0,  0.026855469, 0, ...
        -0.078369141, 0,  0.308593750, 0.501220703, 0.308593750, 0, ...
        -0.078369141, 0,  0.026855469, 0, -0.007812500, 0,  0.001708984, 0, ...
        -0.000244141];

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
