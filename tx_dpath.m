function [y, Fs_out, info] = tx_dpath(x, Fs_in, cfg)
% TX_DPATH  Transmitter digital signal path (baseband complex)
%
% Signal flow (two selectable paths):
%
%   Path 'THB':
%     x --> [TFIR] --> [THB1] --> [THB2] --> [THB3] --> y
%
%   Path 'INT5':
%     x --> [TFIR] --> [THB1] --> [INT5] --> y
%
% Each stage can be individually bypassed via the cfg struct.
% THB2 and THB3 (in the THB path) can also be independently bypassed,
% allowing any combination of {THB2, THB3, both, or neither}.
%
% Syntax:
%   [y, Fs_out]       = tx_dpath(x, Fs_in, cfg)
%   [y, Fs_out, info] = tx_dpath(x, Fs_in, cfg)
%
% Inputs:
%   x      - Complex baseband input signal (column or row vector)
%   Fs_in  - Input sample rate in Hz
%   cfg    - Configuration struct with the following fields:
%
%     .path          - 'THB' (default) or 'INT5'
%                      Selects THB2+THB3 path or INT5 path after THB1.
%
%     .tfir_bypass   - Logical, bypass TFIR stage (default: false)
%     .tfir_h        - TFIR coefficient vector; 20/40/60/80 taps.
%                      Required when tfir_bypass = false.
%     .tfir_interp   - TFIR interpolation: 1, 2, or 4 (default: 1)
%     .tfir_gain_db  - TFIR gain: +6, 0, -6, or -12 dB (default: 0)
%
%     .thb1_bypass   - Logical, bypass THB1 stage (default: false)
%
%     --- Used when path = 'THB' ---
%     .thb2_bypass   - Logical, bypass THB2 (default: false)
%     .thb3_bypass   - Logical, bypass THB3 (default: false)
%
%     --- Used when path = 'INT5' ---
%     .int5_bypass   - Logical, bypass INT5 (default: false)
%                      When bypassed: upsample ×5 (zero-stuff) but no filter.
%
% Outputs:
%   y      - Complex baseband output signal (same orientation as x)
%   Fs_out - Output sample rate in Hz
%   info   - Struct with fields:
%              .rate_in    - Input sample rate (= Fs_in)
%              .rate_tfir  - Rate after TFIR stage
%              .rate_thb1  - Rate after THB1 stage
%              .rate_thb2  - Rate after THB2 stage (THB path only)
%              .rate_thb3  - Rate after THB3 stage (THB path only)
%              .rate_int5  - Rate after INT5 stage (INT5 path only)
%              .total_interp - Overall interpolation factor
%              .path       - Active path string
%              .stage_bypasses - Struct with bypass flags of each stage

    %% ---- Defaults -------------------------------------------------- %%
    if ~isfield(cfg, 'path'),         cfg.path         = 'THB';  end
    if ~isfield(cfg, 'tfir_bypass'),  cfg.tfir_bypass  = false;  end
    if ~isfield(cfg, 'tfir_interp'),  cfg.tfir_interp  = 1;      end
    if ~isfield(cfg, 'tfir_gain_db'), cfg.tfir_gain_db = 0;      end
    if ~isfield(cfg, 'thb1_bypass'),  cfg.thb1_bypass  = false;  end
    if ~isfield(cfg, 'thb2_bypass'),  cfg.thb2_bypass  = false;  end
    if ~isfield(cfg, 'thb3_bypass'),  cfg.thb3_bypass  = false;  end
    if ~isfield(cfg, 'int5_bypass'),  cfg.int5_bypass  = false;  end

    if ~cfg.tfir_bypass && ~isfield(cfg, 'tfir_h')
        error('tx_dpath: cfg.tfir_h is required when tfir_bypass = false.');
    end

    cfg.path = upper(cfg.path);
    if ~ismember(cfg.path, {'THB','INT5'})
        error('tx_dpath: cfg.path must be ''THB'' or ''INT5''.');
    end

    %% ---- Stage processing ------------------------------------------ %%
    Fs = Fs_in;

    % --- TFIR ---
    if cfg.tfir_bypass
        sig = x;
    else
        sig = tfir_filter(x, cfg.tfir_h, cfg.tfir_interp, cfg.tfir_gain_db, false);
        Fs  = Fs * cfg.tfir_interp;
    end
    Fs_after_tfir = Fs;

    % --- THB1 ---
    if ~cfg.thb1_bypass
        sig = thb1_filter(sig, false);
        Fs  = Fs * 2;
    end
    Fs_after_thb1 = Fs;

    % --- THB path or INT5 path ---
    Fs_after_thb2 = NaN;
    Fs_after_thb3 = NaN;
    Fs_after_int5 = NaN;

    if strcmp(cfg.path, 'THB')
        % --- THB2 ---
        if ~cfg.thb2_bypass
            sig = thb2_filter(sig, false);
            Fs  = Fs * 2;
        end
        Fs_after_thb2 = Fs;

        % --- THB3 ---
        if ~cfg.thb3_bypass
            sig = thb3_filter(sig, false);
            Fs  = Fs * 2;
        end
        Fs_after_thb3 = Fs;

    else  % INT5 path
        sig = int5_filter(sig, cfg.int5_bypass);
        Fs  = Fs * 5;
        Fs_after_int5 = Fs;
    end

    y      = sig;
    Fs_out = Fs;

    %% ---- Info struct ----------------------------------------------- %%
    info.rate_in      = Fs_in;
    info.rate_tfir    = Fs_after_tfir;
    info.rate_thb1    = Fs_after_thb1;
    info.rate_thb2    = Fs_after_thb2;
    info.rate_thb3    = Fs_after_thb3;
    info.rate_int5    = Fs_after_int5;
    info.total_interp = Fs_out / Fs_in;
    info.path         = cfg.path;
    info.stage_bypasses.tfir  = cfg.tfir_bypass;
    info.stage_bypasses.thb1  = cfg.thb1_bypass;
    info.stage_bypasses.thb2  = cfg.thb2_bypass;
    info.stage_bypasses.thb3  = cfg.thb3_bypass;
    info.stage_bypasses.int5  = cfg.int5_bypass;
end
