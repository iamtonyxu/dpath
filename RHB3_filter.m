function y = RHB3_filter(x)
% RHB3_FILTER  Receive Half Band 3 fixed-coefficient decimation filter
%
% Syntax:
%   y = RHB3_filter(x)
%
% Input:
%   x - Complex baseband input signal (row or column vector)
%
% Output:
%   y - Complex baseband output signal after decimation by 2
%       (same orientation as x)
%
% RHB3 coefficients (fixed):
%   [-0.033203125, 0, 0.28125, 0.49609375, 0.28125, 0, -0.033203125]

    if ~isvector(x)
        error('RHB3_filter: input x must be a 1-D vector.');
    end

    h = [-0.033203125, 0, 0.28125, 0.49609375, 0.28125, 0, -0.033203125];
    M = 2;

    is_row = isrow(x);
    x = x(:);

    % FIR filtering followed by decimation by 2.
    y = upfirdn(x, h, 1, M);

    if is_row
        y = y.';
    end
end
