function y = rx_pfir_filter(x, h, decim, gain_db, bypass)
% PFIR_FILTER  Rx Programmable FIR decimation filter
%
% The Rx PFIR compensates the analog TIA LPF roll-off and supports
% programmable decimation and gain.
%
% Syntax:
%   y = pfir_filter(x, h)
%   y = pfir_filter(x, h, decim)
%   y = pfir_filter(x, h, decim, gain_db)
%   y = pfir_filter(x, h, decim, gain_db, bypass)
%
% Inputs:
%   x        - Complex baseband input signal (row or column vector)
%   h        - FIR coefficient vector; must have 24, 48, or 72 taps
%   decim    - Decimation factor: 1, 2, or 4 (default: 1)
%   gain_db  - Gain setting: +6, 0, -6, or -12 dB (default: 0)
%   bypass   - Logical flag (default: false)
%                false : apply filtering, gain, and decimation
%                true  : pass-through (output equals input)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : decimated output (factor = decim)
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)

    if nargin < 3 || isempty(decim)
        decim = 1;
    end
    if nargin < 4 || isempty(gain_db)
        gain_db = 0;
    end
    if nargin < 5 || isempty(bypass)
        bypass = false;
    end

    if ~isvector(x)
        error('rx_pfir_filter: input x must be a 1-D vector.');
    end

    n_taps = length(h);
    if ~ismember(n_taps, [24, 48, 72])
        error('rx_pfir_filter: h must have 24, 48, or 72 taps (got %d).', n_taps);
    end

    if ~ismember(decim, [1, 2, 4])
        error('rx_pfir_filter: decim must be 1, 2, or 4 (got %d).', decim);
    end

    if ~ismember(gain_db, [6, 0, -6, -12])
        error('rx_pfir_filter: gain_db must be +6, 0, -6, or -12 dB (got %g).', gain_db);
    end

    gain_lin = 10^(gain_db / 20);

    is_row = isrow(x);
    x = x(:);

    if bypass
        y = x;
    else
        % FIR filtering + decimation by decim.
        y = upfirdn(x, h(:).', 1, decim);

        % Apply programmable gain at PFIR output.
        y = gain_lin * y;
    end

    if is_row
        y = y.';
    end
end
