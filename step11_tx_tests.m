%% STEP 11 - Transmitter tests: output power, modulation characteristics, CFO and drift
% Uses bluetoothRFPHYTestConfig + bluetoothTestWaveform (Bluetooth Toolbox) and
% the measurement helpers from the MathWorks example "Bluetooth LE Transmitter
% Modulation Characteristics, Carrier Frequency Offset and Drift Tests"
% (helperBLEModulationTestConfig / helperBLEModulationTestMeasurements).
% Limits as in that example's helperBLEModulationTestVerdict.m (RF-PHY TS):
%   RF-PHY/TRM/BV-09-C modulation: 225 <= df1avg <= 275 kHz, df2max > 185 kHz
%       for >= 99.9% of samples, df2avg/df1avg > 0.8
%   RF-PHY/TRM/BV-06-C CFO and drift: |f0| <= 150 kHz, |fn - f0| <= 50 kHz,
%       |f1 - f0| <= 23 kHz, |fn - fn-5| <= 20 kHz
%   RF-PHY/TRM/BV-01-C output power: -20 <= Pavg <= +20 dBm, Ppeak <= Pavg + 3 dB
% Two transmitters: Nominal, and Impaired (60 kHz CFO + 30 kHz linear drift over the packet).
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end
addpath(fullfile(matlabroot, 'examples', 'bluetooth', 'main'));

txs = struct('Name', {"Nominal", "Impaired"}, 'CFO_Hz', {0, 60e3}, 'Drift_Hz', {0, 30e3});
Ptx_dBm = 0;                                   % TX output power setting
rows = {};
for d = txs
    fprintf('\n=== TX: %s ===\n', d.Name);
    % --- Modulation characteristics (two payload sequences: 11110000, 10101010)
    cfg = bluetoothRFPHYTestConfig('Test', 'Modulation characteristics', 'Mode', 'LE1M');
    [cp, wg] = helperBLEModulationTestConfig(cfg);
    w = [];
    for s = cp.testSeqIds
        wg.PayloadType = s;
        w = [w, impair(bluetoothTestWaveform(wg), cp.sampleRate, d)]; %#ok<AGROW>
    end
    [~, avgDev, ~, maxDev2] = helperBLEModulationTestMeasurements(w, cfg.TestID, cp);
    df1 = avgDev(1); df2 = avgDev(2); ratio = df2/df1;
    frac = mean(maxDev2 > 185e3);
    rows = [rows; {d.Name, "Mod: df1avg (kHz)", df1/1e3, "225..275", df1 >= 225e3 && df1 <= 275e3}];
    rows = [rows; {d.Name, "Mod: df2max > 185 kHz (% of samples)", 100*frac, ">= 99.9", frac >= 0.999}];
    rows = [rows; {d.Name, "Mod: df2avg/df1avg", ratio, "> 0.8", ratio > 0.8}];

    % --- Carrier frequency offset and drift (payload 10101010)
    cfg = bluetoothRFPHYTestConfig('Test', 'Carrier frequency offset and drift', 'Mode', 'LE1M');
    [cp, wg] = helperBLEModulationTestConfig(cfg);
    wg.PayloadType = cp.testSeqIds;
    w = impair(bluetoothTestWaveform(wg), cp.sampleRate, d);
    [~, f0, fn] = helperBLEModulationTestMeasurements(w, cfg.TestID, cp);
    fn = fn(:);
    dMax  = max(abs(fn - f0));
    d10   = abs(fn(1) - f0);
    d5max = max(abs(fn(6:end) - fn(1:end-5)));
    rows = [rows; {d.Name, "CFO: |f0| (kHz)", abs(f0)/1e3, "<= 150", abs(f0) <= 150e3}];
    rows = [rows; {d.Name, "Drift: max |fn - f0| (kHz)", dMax/1e3, "<= 50", dMax <= 50e3}];
    rows = [rows; {d.Name, "Drift: |f1 - f0| (kHz)", d10/1e3, "<= 23", d10 <= 23e3}];
    rows = [rows; {d.Name, "Drift: max |fn - fn-5| (kHz)", d5max/1e3, "<= 20", d5max <= 20e3}];

    % --- Output power (PRBS9 packet scaled to Ptx_dBm into 1 ohm)
    cfg = bluetoothRFPHYTestConfig('Test', 'Output power', 'Mode', 'LE1M', 'OutputPower', Ptx_dBm);
    wgp = bluetoothTestWaveformConfig('Mode', 'LE1M', 'PayloadType', 0, 'SamplesPerSymbol', 8);
    w = bluetoothTestWaveform(wgp);
    w = w(abs(w) > 0.5*max(abs(w)));             % burst only
    w = w * sqrt(10^((Ptx_dBm - 30)/10) / mean(abs(w).^2));
    w = impair(w, 8e6, d);
    pAvg  = 10*log10(mean(abs(w).^2)) + 30;
    pPeak = 10*log10(max(abs(w).^2)) + 30;
    rows = [rows; {d.Name, "Power: average (dBm)", pAvg, "-20..+20", pAvg >= -20 && pAvg <= 20}];
    rows = [rows; {d.Name, "Power: peak - average (dB)", pPeak - pAvg, "<= 3", pPeak - pAvg <= 3}];
end
T11 = cell2table(rows, 'VariableNames', ["TX","Measurement","Value","Limit","Pass"]);
T11.Verdict = repmat("PASS", height(T11), 1); T11.Verdict(~T11.Pass) = "FAIL";
T11.Pass = [];
disp(T11)
writetable(T11, "results/step11_tx_report.csv");
save("results/step11.mat", "T11", "txs", "Ptx_dBm");

function y = impair(x, fs, d)
% CFO plus a linear carrier drift of d.Drift_Hz over the waveform duration
n = (0:numel(x)-1).' ;
f = d.CFO_Hz + d.Drift_Hz * n / numel(x);
y = x .* exp(1j*2*pi*cumsum(f)/fs);
end
