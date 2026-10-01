%% STEP 1 - BLE waveforms, GFSK and frequency hopping   (~3 min)
% What you learn:
%  - the four LE PHYs: same GFSK modulation, different rate / coding
%  - GFSK = bits become small frequency shifts (about +/-250 kHz for LE1M)
%  - how Channel Selection Algorithm #1 hops, and how AFH removes busy channels
close all;
if ~isfolder("results"), mkdir("results"); end

phys = ["LE1M","LE2M","LE500K","LE125K"];
sps  = 8;
rng(1);
bits = randi([0 1], 37*8, 1);            % 37-byte payload

%% 1a. Spectrum, occupied bandwidth and air time of each PHY
figure('Name','Step 1a - PHY spectra');
tiledlayout(2,2);
T1 = table('Size',[4 4], 'VariableTypes',["string","double","double","double"], ...
    'VariableNames',["PHY","BitRate_kbps","AirTime_us","OBW99_kHz"]);
for i = 1:numel(phys)
    p  = blePhyParams(phys(i));
    fs = p.symRate * sps;
    wf = bleWaveformGenerator(bits, 'Mode', char(phys(i)), 'SamplesPerSymbol', sps);
    [pxx, f] = pwelch(wf, [], [], [], fs, 'centered');
    nexttile;
    plot(f/1e6, 10*log10(pxx)); grid on; xlim([-3 3]);
    xlabel('Frequency offset (MHz)'); ylabel('PSD (dB/Hz)'); title(phys(i));
    T1(i,:) = {phys(i), p.bitRate/1e3, numel(wf)/fs*1e6, obw(wf, fs)/1e3};
end
disp(T1)
% Read it: LE2M is ~2x wider; coded PHYs have the same spectrum as LE1M
% but ~2x / ~8x longer air time for the same payload.

%% 1b. GFSK: look at the instantaneous frequency
p  = blePhyParams("LE1M");
fs = p.symRate * sps;
wf = bleWaveformGenerator(bits, 'Mode', 'LE1M', 'SamplesPerSymbol', sps);
instF = diff(unwrap(angle(wf))) * fs / (2*pi);
nShow = 40 * sps;
figure('Name','Step 1b - GFSK');
plot((1:nShow)/sps, instF(1:nShow)/1e3); grid on;
xlabel('Symbol'); ylabel('Instantaneous frequency (kHz)');
title('LE1M GFSK: each bit is a frequency shift of about \pm250 kHz');

%% 1c. Frequency hopping (CSA #1) with and without AFH around Wi-Fi channel 6
ch   = 0:36;
fMHz = bleChanFreqMHz(ch);
wifiCenter = 2437; wifiHalfBW = 10;                 % Wi-Fi ch 6, 20 MHz wide
bad     = wifiOverlap(fMHz, wifiCenter, 2*wifiHalfBW); % BLE channels hit by Wi-Fi
usedAFH = ch(~bad);

nEvents = 100; hop = 7;
seqAll = csa1(ch,      hop, nEvents);
seqAFH = csa1(usedAFH, hop, nEvents);

hitsAll = sum(bad(seqAll + 1));
hitsAFH = sum(bad(seqAFH + 1));

figure('Name','Step 1c - Hopping');
patch([0 nEvents+1 nEvents+1 0], ...
      [wifiCenter-wifiHalfBW wifiCenter-wifiHalfBW wifiCenter+wifiHalfBW wifiCenter+wifiHalfBW], ...
      'r', 'FaceAlpha', 0.12, 'EdgeColor', 'none'); hold on;
plot(1:nEvents, bleChanFreqMHz(seqAll), 'o-');
plot(1:nEvents, bleChanFreqMHz(seqAFH), 's-');
grid on; xlabel('Connection event'); ylabel('RF channel (MHz)');
legend('Wi-Fi ch 6','No AFH','AFH (Wi-Fi channels removed)', 'Location','best');
title(sprintf('Hops landing in Wi-Fi: no AFH %d/%d, AFH %d/%d', hitsAll, nEvents, hitsAFH, nEvents));
fprintf('\nBLE channels blocked by Wi-Fi ch 6: %d of 37\n', sum(bad));
fprintf('Hops into Wi-Fi band: no AFH %d/%d, with AFH %d/%d\n', hitsAll, nEvents, hitsAFH, nEvents);

save("results/step1.mat", "T1", "hitsAll", "hitsAFH", "nEvents", "bad");

%% ---- local function ----
function seq = csa1(used, hop, n)
% Channel Selection Algorithm #1 (Core spec, Vol 6 Part B 4.5.8.2):
% unmapped = (last + hop) mod 37; if unused, remap into the used-channel list.
seq  = zeros(1, n);
last = 0;
for k = 1:n
    unmapped = mod(last + hop, 37);
    if ismember(unmapped, used)
        seq(k) = unmapped;
    else
        seq(k) = used(mod(unmapped, numel(used)) + 1);
    end
    last = unmapped;
end
end
