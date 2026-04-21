function [y, Fs_out, info] = rx_dpath(x, Fs_in, cfg)
% RX_DPATH  Receiver digital path (baseband complex)
%
% Supported chain:
%   Front-end selection (choose one):
%     A) DEC5
%     B) FIR2 -> FIR1 -> RHB3   (configurable to decimate by 2/4/8)
%
%   Followed by:
%     RHB2 -> (HR or LP) -> PFIR
%
% Syntax:
%   [y, Fs_out]       = rx_dpath(x, Fs_in, cfg)
%   [y, Fs_out, info] = rx_dpath(x, Fs_in, cfg)
%
% Inputs:
%   x      - Complex baseband input signal (row or column vector)
%   Fs_in  - Input sample rate in Hz
%   cfg    - Configuration struct
%
% Required/optional cfg fields:
%   .front_path   - 'DEC5' or 'FIR_CHAIN'  (default: 'DEC5')
%
%   -- Used for DEC5 front path --
%   .dec5_bypass  - Logical (default: false)
%
%   -- Used for FIR_CHAIN front path --
%   .fir2_bypass  - Logical (default: false)
%   .fir1_bypass  - Logical (default: false)
%   % RHB3 is always active in FIR_CHAIN mode (fixed decimate-by-2).
%   % This yields front-end decimation factors:
%   %   FIR2/FIR1 both bypassed  -> x2
%   %   one enabled              -> x4
%   %   both enabled             -> x8
%
%   -- Mid stage --
%   .rhb2_bypass   - Logical (default: false)
%
%   -- RHB1 selection (exactly one active) --
%   .rhb1_mode     - 'HR' or 'LP' (default: 'HR')
%   .hr_bypass     - Logical (default: false)
%   .lp_bypass     - Logical (default: false)
%   % Note: only the selected branch bypass flag is applied.
%
%   -- PFIR stage --
%   .pfir_bypass   - Logical (default: false)
%   .pfir_h        - PFIR coefficients (24/48/72 taps), required when
%                    pfir_bypass=false
%   .pfir_decim    - 1, 2, or 4 (default: 1)
%   .pfir_gain_db  - +6, 0, -6, -12 (default: 0)
%
% Outputs:
%   y      - Output baseband signal
%   Fs_out - Output sample rate in Hz
%   info   - Struct with stage sample rates and total decimation

    if ~isvector(x)
        error('rx_dpath: input x must be a 1-D vector.');
    end

    %% -------------------- defaults ---------------------------------- %%
    if ~isfield(cfg, 'front_path'),  cfg.front_path = 'DEC5'; end
    if ~isfield(cfg, 'dec5_bypass'), cfg.dec5_bypass = false; end

    if ~isfield(cfg, 'fir2_bypass'), cfg.fir2_bypass = false; end
    if ~isfield(cfg, 'fir1_bypass'), cfg.fir1_bypass = false; end

    if ~isfield(cfg, 'rhb2_bypass'), cfg.rhb2_bypass = false; end

    if ~isfield(cfg, 'rhb1_mode'),   cfg.rhb1_mode = 'HR'; end
    if ~isfield(cfg, 'hr_bypass'),   cfg.hr_bypass = false; end
    if ~isfield(cfg, 'lp_bypass'),   cfg.lp_bypass = false; end

    if ~isfield(cfg, 'pfir_bypass'),  cfg.pfir_bypass = false; end
    if ~isfield(cfg, 'pfir_decim'),   cfg.pfir_decim = 1; end
    if ~isfield(cfg, 'pfir_gain_db'), cfg.pfir_gain_db = 0; end

    if ~cfg.pfir_bypass && ~isfield(cfg, 'pfir_h')
        error('rx_dpath: cfg.pfir_h is required when pfir_bypass = false.');
    end

    cfg.front_path = upper(cfg.front_path);
    cfg.rhb1_mode  = upper(cfg.rhb1_mode);

    if ~ismember(cfg.front_path, {'DEC5', 'FIR_CHAIN'})
        error('rx_dpath: cfg.front_path must be ''DEC5'' or ''FIR_CHAIN''.');
    end

    if ~ismember(cfg.rhb1_mode, {'HR', 'LP'})
        error('rx_dpath: cfg.rhb1_mode must be ''HR'' or ''LP''.');
    end

    %% -------------------- processing -------------------------------- %%
    Fs = Fs_in;
    sig = x;

    % Stage-rate bookkeeping
    rate_front = NaN;
    rate_fir2  = NaN;
    rate_fir1  = NaN;
    rate_rhb3  = NaN;
    rate_dec5  = NaN;

    % ---- Front path selection ----
    switch cfg.front_path
        case 'DEC5'
            sig = rx_dec5_filter(sig, cfg.dec5_bypass);
            if ~cfg.dec5_bypass
                Fs = Fs / 5;
            end
            rate_dec5 = Fs;
            rate_front = Fs;

        case 'FIR_CHAIN'
            sig = rx_FIR2(sig, cfg.fir2_bypass);
            if ~cfg.fir2_bypass
                Fs = Fs / 2;
            end
            rate_fir2 = Fs;

            sig = rx_FIR1(sig, cfg.fir1_bypass);
            if ~cfg.fir1_bypass
                Fs = Fs / 2;
            end
            rate_fir1 = Fs;

            % RHB3 is mandatory in FIR_CHAIN path.
            sig = rx_RHB3_filter(sig);
            Fs = Fs / 2;
            rate_rhb3 = Fs;
            rate_front = Fs;
    end

    % ---- RHB2 ----
    sig = rx_RHB2_filter(sig, cfg.rhb2_bypass);
    if ~cfg.rhb2_bypass
        Fs = Fs / 2;
    end
    rate_rhb2 = Fs;

    % ---- HR / LP (select one) ----
    switch cfg.rhb1_mode
        case 'HR'
            sig = rx_HR_filter(sig, cfg.hr_bypass);
            if ~cfg.hr_bypass
                Fs = Fs / 2;
            end
        case 'LP'
            sig = rx_LP_filter(sig, cfg.lp_bypass);
            if ~cfg.lp_bypass
                Fs = Fs / 2;
            end
    end
    rate_rhb1 = Fs;

    % ---- PFIR ----
    if cfg.pfir_bypass
        % Bypass keeps signal and sample rate unchanged.
        sig = sig;
    else
        sig = rx_pfir_filter(sig, cfg.pfir_h, cfg.pfir_decim, cfg.pfir_gain_db, false);
        Fs = Fs / cfg.pfir_decim;
    end
    rate_pfir = Fs;

    y = sig;
    Fs_out = Fs;

    %% -------------------- info -------------------------------------- %%
    info.front_path = cfg.front_path;
    info.rhb1_mode  = cfg.rhb1_mode;

    info.rate_in    = Fs_in;
    info.rate_front = rate_front;
    info.rate_fir2  = rate_fir2;
    info.rate_fir1  = rate_fir1;
    info.rate_rhb3  = rate_rhb3;
    info.rate_dec5  = rate_dec5;
    info.rate_rhb2  = rate_rhb2;
    info.rate_rhb1  = rate_rhb1;
    info.rate_pfir  = rate_pfir;
    info.rate_out   = Fs_out;

    info.total_decim = Fs_in / Fs_out;

    info.stage_bypass.dec5 = cfg.dec5_bypass;
    info.stage_bypass.fir2 = cfg.fir2_bypass;
    info.stage_bypass.fir1 = cfg.fir1_bypass;
    info.stage_bypass.rhb2 = cfg.rhb2_bypass;
    info.stage_bypass.hr   = cfg.hr_bypass;
    info.stage_bypass.lp   = cfg.lp_bypass;
    info.stage_bypass.pfir = cfg.pfir_bypass;
end
