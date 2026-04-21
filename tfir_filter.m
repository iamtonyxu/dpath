function y = tfir_filter(x, h, interp, gain_db, bypass)
% TFIR_FILTER  TFIR programmable interpolation filter (Tx digital path)
%
% The TFIR compensates for roll-off caused by the post-DAC analog LPF.
% It supports configurable interpolation, tap count, and gain.
%
% Syntax:
%   y = tfir_filter(x, h)
%   y = tfir_filter(x, h, interp)
%   y = tfir_filter(x, h, interp, gain_db)
%   y = tfir_filter(x, h, interp, gain_db, bypass)
%
% Inputs:
%   x        - Complex baseband input signal (column or row vector)
%   h        - FIR coefficient vector; must have 20, 40, 60, or 80 taps
%   interp   - Interpolation factor: 1, 2, or 4  (default: 1)
%   gain_db  - Gain setting in dB: +6, 0, -6, or -12  (default: 0)
%   bypass   - Logical flag (default: false)
%                false : apply interpolation, filtering, and gain
%                true  : pass input through unchanged (no rate change)
%
% Output:
%   y - Complex baseband output signal
%       bypass=false : length(y) = interp * length(x)
%       bypass=true  : length(y) = length(x)
%       (same orientation as x)
%
% Notes:
%   - Coefficient normalisation: the caller is responsible for designing h
%     such that the desired passband response (excluding the gain_db offset)
%     is achieved at the output sample rate.
%   - The gain_db setting applies a linear scale to the output AFTER
%     filtering: +6 dB → ×2, 0 dB → ×1, -6 dB → ×0.5, -12 dB → ×0.25.

    %% ---- Input validation -------------------------------------------
    if nargin < 3 || isempty(interp),  interp  = 1;     end
    if nargin < 4 || isempty(gain_db), gain_db = 0;     end
    if nargin < 5 || isempty(bypass),  bypass  = false; end

    if ~isvector(x)
        error('tfir_filter: x must be a 1-D vector.');
    end

    valid_taps = [20, 40, 60, 80];
    N_taps = length(h);
    if ~ismember(N_taps, valid_taps)
        error('tfir_filter: h must have 20, 40, 60, or 80 taps (got %d).', N_taps);
    end

    valid_interp = [1, 2, 4];
    if ~ismember(interp, valid_interp)
        error('tfir_filter: interp must be 1, 2, or 4 (got %d).', interp);
    end

    valid_gain = [6, 0, -6, -12];
    if ~ismember(gain_db, valid_gain)
        error('tfir_filter: gain_db must be +6, 0, -6, or -12 dB (got %g).', gain_db);
    end

    %% ---- Gain linear scale ------------------------------------------
    gain_lin = 10^(gain_db / 20);

    %% ---- Processing ---------------------------------------------------
    is_row = isrow(x);
    x      = x(:);          % column vector
    N_in   = length(x);
    N_out  = interp * N_in;
    group_delay = (N_taps - 1) / 2;    % linear-phase FIR assumed

    if bypass
        y = x;

    else
        % upfirdn: upsample by interp, convolve with h
        % Output length = N_in*interp + N_taps - 1
        y_full = upfirdn(x, h(:).', interp, 1);

        % Compensate group delay and trim to exact output length
        start_idx = group_delay + 1;
        y = y_full(start_idx : start_idx + N_out - 1);

        % Apply programmable gain
        y = gain_lin * y;
    end

    if is_row
        y = y.';
    end
end
