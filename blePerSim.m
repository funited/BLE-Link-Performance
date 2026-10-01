function [per, ber] = blePerSim(phy, EbNo_dB, opts)
%BLEPERSIM Link-level BLE PHY simulation: TX -> channel/impairments -> RX.
%   [per, ber] = blePerSim("LE1M", 0:2:10)
%   Options: NumPackets, MaxPacketErrors, PayloadBytes, SamplesPerSymbol,
%            CFO_Hz (carrier frequency offset), CI_dB (co-channel interferer
%            carrier-to-interference ratio; Inf = none), Receiver, StopAtZero, Seed.
%   Receiver: "ideal"         - bleIdealReceiver: coherent, assumes zero carrier
%                               phase, no CFO tracking (breaks within ~2 kHz CFO)
%             "discriminator" - noncoherent 1-symbol differential detector with
%                               CFO estimated on the known preamble + access
%                               address, like a real BLE chip. Coded PHYs feed
%                               its soft outputs into the toolbox FEC decoder.
%   Channel:  "awgn" (default), "rician", "rayleigh". Indoor profile: delays
%             [0 50 100 150] ns, gains [0 -3 -6 -9] dB, K = 6 dB (Rician),
%             3 Hz max Doppler, new fading realization every packet (block fading).
%   RX impairments (defaults = none):
%     TimingDrift_ppm  - sample-clock error, RX waveform resampled by (1 + ppm*1e-6)
%     PhaseNoise_dBcHz - LO phase noise level at 100 kHz offset (comm.PhaseNoise)
%     DCOffset         - DC offset as a fraction of the wanted signal RMS
%   Interference (C/I = wanted power / power of EACH interferer, in dB):
%     Intf_Type      - "none" (default), "ble" (modulated BLE packet), "cw",
%                      "twotone" (CW at Intf_Offset_Hz(1) + BLE at Intf_Offset_Hz(2)),
%                      "wifi" (Gaussian noise, flat over Intf_BW_Hz centred at
%                      Intf_Offset_Hz; C/I uses its TOTAL power over that band;
%                      only the part inside +/-fs/2 is generated)
%     Intf_BW_Hz     - bandwidth of the "wifi" interferer (default 20 MHz)
%     Intf_WifiMask  - true: shape the "wifi" noise with the 802.11 OFDM 20 MHz
%                      transmit spectral mask (0 dBr to 9 MHz, -20 dBr at 11 MHz,
%                      -28 dBr at 20 MHz, -40 dBr from 30 MHz) instead of a flat band
%     Intf_Offset_Hz - interferer frequency offset(s) from the wanted carrier
%     Intf_CI_dB     - C/I in dB
%   Absolute levels (needed for the receiver nonlinearity):
%     WantedLevel_dBm - wanted power at the antenna (NaN = relative mode)
%     IIP3_dBm        - 3rd-order input intercept of the RX front end
%                       (comm.MemorylessNonlinearity, cubic polynomial; Inf = linear)
arguments
    phy (1,1) string
    EbNo_dB (1,:) double
    opts.NumPackets (1,1) double = 200
    opts.MaxPacketErrors (1,1) double = 100
    opts.PayloadBytes (1,1) double = 37
    opts.SamplesPerSymbol (1,1) double = 4
    opts.CFO_Hz (1,1) double = 0
    opts.CI_dB (1,1) double = Inf
    opts.Receiver (1,1) string {mustBeMember(opts.Receiver, ["ideal","discriminator"])} = "ideal"
    opts.Channel (1,1) string {mustBeMember(opts.Channel, ["awgn","rician","rayleigh"])} = "awgn"
    opts.TimingDrift_ppm (1,1) double = 0
    opts.PhaseNoise_dBcHz (1,1) double = -Inf
    opts.DCOffset (1,1) double = 0
    opts.Intf_Type (1,1) string {mustBeMember(opts.Intf_Type, ["none","ble","cw","twotone","wifi"])} = "none"
    opts.Intf_BW_Hz (1,1) double = 20e6
    opts.Intf_WifiMask (1,1) logical = false
    opts.Intf_Offset_Hz (1,:) double = 0
    opts.Intf_CI_dB (1,1) double = Inf
    opts.WantedLevel_dBm (1,1) double = NaN
    opts.IIP3_dBm (1,1) double = Inf
    opts.StopAtZero (1,1) logical = true
    opts.Seed (1,1) double = 42
end

rng(opts.Seed);
p    = blePhyParams(phy);
sps  = opts.SamplesPerSymbol;
fs   = p.symRate * sps;
mode = char(phy);
nBitsPkt = opts.PayloadBytes * 8;
useDisc  = opts.Receiver == "discriminator";
if isfinite(opts.IIP3_dBm) && isnan(opts.WantedLevel_dBm)
    error("IIP3_dBm needs WantedLevel_dBm (absolute signal levels).");
end

% Fading channel (block fading: reset every packet, global random stream so
% every packet gets a new realization)
chan = [];
if opts.Channel ~= "awgn"
    common = {'SampleRate', fs, 'PathDelays', [0 50 100 150]*1e-9, ...
        'AveragePathGains', [0 -3 -6 -9], 'NormalizePathGains', true, ...
        'MaximumDopplerShift', 3, 'RandomStream', 'Global stream'};
    if opts.Channel == "rician"
        chan = comm.RicianChannel(common{:}, 'KFactor', 10^(6/10));
    else
        chan = comm.RayleighChannel(common{:});
    end
    chanDelay = info(chan).ChannelFilterDelay;
end
pn = [];
if isfinite(opts.PhaseNoise_dBcHz)
    pn = comm.PhaseNoise('Level', opts.PhaseNoise_dBcHz, 'FrequencyOffset', 100e3, ...
        'SampleRate', fs);
end
nl = [];
if isfinite(opts.IIP3_dBm)
    nl = comm.MemorylessNonlinearity('Method', 'Cubic polynomial', ...
        'LinearGain', 0, 'IIP3', opts.IIP3_dBm, 'ReferenceImpedance', 1);
end

per = nan(size(EbNo_dB));
ber = per;

for k = 1:numel(EbNo_dB)
    % Eb/No -> per-sample SNR.
    % GFSK carries 1 coded bit per symbol; coding (S=2 / S=8) spreads each
    % information bit over 2 / 8 symbols, and oversampling spreads the
    % noise over sps samples per symbol.
    snr = EbNo_dB(k) + 10*log10(p.codeRate) - 10*log10(sps);

    pktErr = 0; bitErr = 0; nPkt = 0;
    while nPkt < opts.NumPackets && pktErr < opts.MaxPacketErrors
        txBits = randi([0 1], nBitsPkt, 1);
        tx = bleWaveformGenerator(txBits, 'Mode', mode, 'SamplesPerSymbol', sps);
        sigPow_dBW = 10*log10(mean(abs(tx).^2));
        rx = tx;
        t  = (0:numel(rx)-1).' / fs;

        % Multipath fading (delay of the channel filter removed)
        if ~isempty(chan)
            reset(chan);
            y  = chan([rx; zeros(chanDelay, 1)]);
            rx = y(chanDelay+1:end);
        end

        % RF impairment: carrier frequency offset (same place in the chain
        % as before, so existing results are reproduced exactly)
        if opts.CFO_Hz ~= 0
            rx = rx .* exp(1j*2*pi*opts.CFO_Hz*t);
        end

        % Absolute level of the wanted signal (for the nonlinearity)
        if ~isnan(opts.WantedLevel_dBm)
            aW = sqrt(10^((opts.WantedLevel_dBm - 30)/10) / 10^(sigPow_dBW/10));
            rx = aW * rx;
            sigPow_dBW = opts.WantedLevel_dBm - 30;
        end
        pW = 10^(sigPow_dBW/10);                 % wanted power (W)

        % Co-channel interferer: another BLE packet at a given C/I
        if isfinite(opts.CI_dB)
            intf = bleWaveformGenerator(randi([0 1], nBitsPkt, 1), ...
                'Mode', mode, 'SamplesPerSymbol', sps);
            intf = circshift(intf, randi(numel(intf)));
            g  = sqrt(pW / mean(abs(intf).^2) / 10^(opts.CI_dB/10));
            rx = rx + g*intf;
        end

        % Interferers at a frequency offset
        if opts.Intf_Type ~= "none"
            pI = pW / 10^(opts.Intf_CI_dB/10);   % power of each interferer
            switch opts.Intf_Type
                case "ble"
                    rx = rx + offsetBle(pI, opts.Intf_Offset_Hz(1), numel(rx), mode, sps, nBitsPkt, t);
                case "cw"
                    rx = rx + sqrt(pI) * exp(1j*(2*pi*opts.Intf_Offset_Hz(1)*t + 2*pi*rand));
                case "twotone"
                    rx = rx + sqrt(pI) * exp(1j*(2*pi*opts.Intf_Offset_Hz(1)*t + 2*pi*rand)) ...
                            + offsetBle(pI, opts.Intf_Offset_Hz(2), numel(rx), mode, sps, nBitsPkt, t);
                case "wifi"
                    rx = rx + bandNoise(pI, opts.Intf_Offset_Hz(1), opts.Intf_BW_Hz, numel(rx), fs, opts.Intf_WifiMask);
            end
        end

        % Thermal noise (input-referred, relative to the wanted signal)
        rx = awgn(rx, snr, sigPow_dBW);

        % Front-end 3rd-order nonlinearity (LNA/mixer)
        if ~isempty(nl)
            rx = nl(rx);
        end

        % LO phase noise
        if ~isempty(pn)
            rx = pn(rx);
        end

        % Sample-clock drift: resample the received waveform
        if opts.TimingDrift_ppm ~= 0
            n0 = (0:numel(rx)-1).';
            rx = interp1(n0, rx, n0*(1 + opts.TimingDrift_ppm*1e-6), 'spline', 0);
        end

        % DC offset (fraction of wanted RMS)
        if opts.DCOffset ~= 0
            rx = rx + opts.DCOffset * sqrt(pW);
        end

        % Back to unit scale for the receiver (it is scale-invariant anyway)
        if ~isnan(opts.WantedLevel_dBm)
            rx = rx / aW;
        end

        if useDisc && p.codeRate ~= 1
            e = discriminatorErrorsCoded(rx, tx, mode, sps, fs, nBitsPkt);
        elseif useDisc
            % Noncoherent receiver: compares on-air (whitened) bits, which
            % gives the same error count because whitening is a bitwise XOR.
            e = discriminatorErrors(rx, tx, mode, sps, fs, nBitsPkt);
        else
            % Ideal receiver (demodulation, decoding, de-whitening)
            rxBits = bleIdealReceiver(rx, 'Mode', mode, 'SamplesPerSymbol', sps);
            n = min(numel(rxBits), nBitsPkt);
            e = sum(double(rxBits(1:n)) ~= txBits(1:n)) + (nBitsPkt - n);
        end
        bitErr = bitErr + e;
        pktErr = pktErr + (e > 0);
        nPkt   = nPkt + 1;
    end

    per(k) = pktErr / nPkt;
    ber(k) = bitErr / (nPkt * nBitsPkt);
    fprintf('  %-6s Eb/No %5.1f dB  PER %.3f  BER %.2e  (%d pkts)\n', ...
        phy, EbNo_dB(k), per(k), ber(k), nPkt);

    if opts.StopAtZero && pktErr == 0   % curve has hit the floor; save time
        per(k+1:end) = 0;
        ber(k+1:end) = 0;
        break
    end
end
end

%% ---- local functions ----
function e = discriminatorErrors(rx, tx, mode, sps, fs, nBitsPkt)
% 1-symbol differential detector: the phase change over one symbol is about
% +/-pi/2 for BLE GFSK (h = 0.5); its sign is the bit. A CFO adds a constant
% 2*pi*CFO*T to every phase change, so estimate it and subtract it.
nHdr = 8*(mode == "LE1M") + 16*(mode == "LE2M") + 32;   % preamble + access address (symbols)
[dRx, dRef] = discriminate(rx, tx, nHdr, sps, fs);

% Compare only the PDU bits after the header
pdu = nHdr + (1:nBitsPkt) - 1;
pdu = pdu(pdu <= numel(dRef));
e   = sum((dRx(pdu) > 0) ~= (dRef(pdu) > 0)) + (nBitsPkt - numel(pdu));
end

function e = discriminatorErrorsCoded(rx, tx, mode, sps, fs, nBitsPkt)
% Coded PHYs: the discriminator's soft phase changes replace the coherent
% demodulator's output and go into the toolbox FEC decoder (pattern demap +
% Viterbi). Errors are counted against the same decoder run on the clean
% reference, so no de-whitening is needed (whitening is a bitwise XOR).
prbSym = 80;
nHdr   = prbSym + 32*8;           % preamble + coded access address, both known

% Flush the channel filter so the last symbols are not cut off
pad = zeros(16*sps, 1);
[dRx, dRef] = discriminate([rx; pad], [tx; pad], nHdr, sps, fs);

% Line the discriminator up with what the decoder expects: the coherent
% demodulator's output on the clean reference (sign + symbol lag)
g = ble.internal.gmskdemod(tx(prbSym*sps+1:end), sps);
n = numel(g);
bestScore = -Inf;
for lag = prbSym-8:prbSym+8
    for sgn = [1 -1]
        seg   = dRef(lag + (1:min(n, numel(dRef)-lag)));
        score = mean(sign(sgn*seg) == sign(g(1:numel(seg))));
        if score > bestScore, bestScore = score; bestLag = lag; bestSgn = sgn; end
    end
end
m    = min(n, numel(dRx) - bestLag);
soft = zeros(n, 1);
soft(1:m) = bestSgn * dRx(bestLag + (1:m));
ref       = zeros(n, 1);
ref(1:m)  = bestSgn * dRef(bestLag + (1:m));

bitsRx  = ble.internal.decode(soft, mode);
bitsRef = ble.internal.decode(ref,  mode);
k = min([numel(bitsRx), numel(bitsRef), nBitsPkt]);
e = sum(bitsRx(1:k) ~= bitsRef(1:k)) + (nBitsPkt - k);
end

function [dRx, dRef] = discriminate(rx, tx, nHdr, sps, fs)
% Filter, estimate CFO on the first nHdr (known) symbols, then return the
% CFO-corrected symbol-spaced phase changes of rx and of the clean reference.
L = nHdr * sps;

% Channel-select filter (~1.2x symbol rate wide) so the detector does not see
% noise across the whole sample bandwidth. The reference gets the same filter.
b  = fir1(8*sps, 1.2/sps);
rx = filter(b, 1, rx);
tx = filter(b, 1, tx);

% CFO estimate on the known header: strip the modulation with the known
% reference, then coarse (lag 1, +/-fs/2 range) and fine (lag sps) estimates.
z  = rx(1:L) .* conj(tx(1:L));
f1 = angle(sum(z(2:end) .* conj(z(1:end-1)))) * fs / (2*pi);
t  = (0:L-1).' / fs;
z  = z .* exp(-1j*2*pi*f1*t);
f2 = angle(sum(z(1+sps:end) .* conj(z(1:end-sps)))) * fs / (2*pi*sps);
cfoHat = f1 + f2;

% Symbol-spaced phase differences at the best sampling offset (found on the
% clean reference, i.e. ideal timing recovery)
nSym = floor(numel(tx) / sps) - 1;
best = 0; bestEye = -Inf;
for o = 1:sps
    idx = o + (0:nSym) * sps;
    eye = mean(abs(angle(tx(idx(2:end)) .* conj(tx(idx(1:end-1))))));
    if eye > bestEye, bestEye = eye; best = o; end
end
idx   = best + (0:nSym) * sps;
dRef  = angle(tx(idx(2:end)) .* conj(tx(idx(1:end-1))));
dRx   = angle(rx(idx(2:end)) .* conj(rx(idx(1:end-1))) .* exp(-1j*2*pi*cfoHat*sps/fs));
end

function y = offsetBle(pI, fOff, n, mode, sps, nBitsPkt, t)
% Modulated BLE interferer with power pI at frequency offset fOff, random start.
y = bleWaveformGenerator(randi([0 1], nBitsPkt, 1), 'Mode', mode, 'SamplesPerSymbol', sps);
y = circshift(y, randi(numel(y)));
y = y(1 + mod(0:n-1, numel(y)));
y = sqrt(pI / mean(abs(y).^2)) * y .* exp(1j*2*pi*fOff*t);
end

function y = bandNoise(pTot, fc, bw, n, fs, useMask)
% Complex Gaussian noise centred at fc with total power pTot. Flat over bw, or
% (useMask) shaped by the 802.11 OFDM 20 MHz transmit spectral mask. Only the
% part inside [-fs/2, fs/2) is generated (FFT shaping of white noise).
shape = @(df) double(abs(df) <= bw/2);
if useMask
    mk = [0 9e6 11e6 20e6 30e6 1e9; 0 0 -20 -28 -40 -40];
    shape = @(df) 10.^(interp1(mk(1,:), mk(2,:), abs(df)) / 10);
end
fAll = (-60e6:10e3:60e6).';
psd0 = pTot / (sum(shape(fAll)) * 10e3);         % PSD at 0 dBr so the total is pTot
f = (-floor(n/2):ceil(n/2)-1).' * fs / n;
X = (randn(n, 1) + 1j*randn(n, 1)) / sqrt(2) .* sqrt(shape(f - fc));
y = ifft(ifftshift(X)) * sqrt(n);                % unit PSD per bin where shape = 1
y = y * sqrt(psd0 * fs);
end