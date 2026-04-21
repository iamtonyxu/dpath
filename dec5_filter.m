function y = dec5_filter(x, bypass)
% DEC5_FILTER  DEC5 decimation filter (decimation factor M = 5)
%
% Syntax:
%   y = dec5_filter(x)
%   y = dec5_filter(x, bypass)
%
% Inputs:
%   x      - Complex baseband input signal (column or row vector)
%   bypass - Logical flag (default: false)
%              false : apply DEC5 FIR then decimate by 5
%              true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : approximately length(x)/5
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% Filter spec (fixed coefficients):
%   33-tap linear-phase symmetric FIR, decimation by 5.

    if nargin < 2
        bypass = false;
    end

    if ~isvector(x)
        error('dec5_filter: input x must be a 1-D vector.');
    end

    % DEC5 filter coefficients (from specification)
    h = [ ...
         0.000976563,  0.001220703,  0.001953125,  0.001953125, -0.003906250, ...
        -0.007812500, -0.014648438, -0.018798828, -0.019042969, -0.007568359, ...
         0.010742188,  0.041748047,  0.079101563,  0.117187500,  0.146972656, ...
         0.165527344,  0.165527344,  0.146972656,  0.117187500,  0.079101563, ...
         0.041748047,  0.010742188, -0.007568359, -0.019042969, -0.018798828, ...
        -0.014648438, -0.007812500, -0.003906250,  0.001220703,  0.001953125, ...
         0.001953125,  0.001220703,  0.000976563];

    M = 5;  % Decimation factor

    is_row = isrow(x);
    x = x(:);

    if bypass
        y = x;
    else
        % Apply FIR + decimate by 5 in one step.
        y = upfirdn(x, h, 1, M);
    end

    if is_row
        y = y.';
    end
end
