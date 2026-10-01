%% STEP 10 - Receiver interference tests: C/I, blocking, intermodulation
% Test levels follow the MathWorks example "Bluetooth LE Blocking,
% Intermodulation and Carrier-to-Interference Performance Tests" - its helper
% helperBLETestParamGenerate.m (Bluetooth RF-PHY Test Spec, section 4.5), LE1M:
%   C/I:     wanted -67 dBm; interferer (modulated BLE) -88 dBm co-channel,
%            -82 dBm at +/-1 MHz, -50 dBm at +/-2 MHz, -40 dBm at >= 3 MHz
%   Blocking: wanted -67 dBm; CW blocker -35 dBm in 2003-2399 MHz. Here the
%            closest spec point to Fc = 2426 MHz: 2399 MHz (-27 MHz offset)
%   Intermodulation: wanted -64 dBm; CW at Fc+n MHz and modulated BLE at
%            Fc+2n MHz, both -50 dBm (n = 3 here), so 2*f1 - f2 = Fc
%   PER limit 30.8%.
% Plus the three Step 5 tests (sensitivity LE1M / LE125K, co-channel at Eb/No 20 dB).
% Thermal noise from the absolute wanted level with a 7 dB noise figure.
% Receiver front end: 3rd-order nonlinearity with IIP3 (assumed nominal -20 dBm).
% Discriminator receiver, 500 packets per test.
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end
R5 = load("results/step5.mat");        % sensitivity reference levels from Step 5
S2 = load("results/step2_per.mat");
NF = S2.NF; NP = 500; limit = 0.308;
IIP3nom = -20;                         % dBm, assumed nominal front end

duts = struct('Name', {"Nominal", "Degraded", "Nonlinear"}, ...
              'CFO_Hz', {0, 150e3, 0}, ...
              'ExtraLoss_dB', {0, 4, 0}, ...
              'IIP3_dBm', {IIP3nom, IIP3nom, IIP3nom - 10});

% name, wanted dBm (NaN = relative Eb/No test), interferer type, offsets (Hz), C/I dB, sps, PHY, Eb/No
tests = {
  "LE1M sensitivity",           NaN, "none",    0,          Inf,  4, "LE1M",   R5.ref1
  "LE125K sensitivity",         NaN, "none",    0,          Inf,  4, "LE125K", R5.refc
  "Step5 co-channel C/I 21 dB", NaN, "ble",     0,          21,   4, "LE1M",   20
  "C/I co-channel",             -67, "ble",     0,          21,   16, "LE1M",  NaN
  "C/I +1 MHz",                 -67, "ble",     1e6,        15,   16, "LE1M",  NaN
  "C/I -1 MHz",                 -67, "ble",     -1e6,       15,   16, "LE1M",  NaN
  "C/I +2 MHz",                 -67, "ble",     2e6,        -17,  16, "LE1M",  NaN
  "C/I -2 MHz",                 -67, "ble",     -2e6,       -17,  16, "LE1M",  NaN
  "C/I +3 MHz",                 -67, "ble",     3e6,        -27,  16, "LE1M",  NaN
  "C/I -3 MHz",                 -67, "ble",     -3e6,       -27,  16, "LE1M",  NaN
  "Blocking CW 2399 MHz",       -67, "cw",      -27e6,      -32,  64, "LE1M",  NaN
  "Intermod n=3 (+3/+6 MHz)",   -64, "twotone", [3e6 6e6],  -14,  16, "LE1M",  NaN
};

results = table();
for d = duts
    fprintf('\n=== DUT: %s ===\n', d.Name);
    for i = 1:size(tests, 1)
        [name, wl, ityp, foff, ci, sps, phy, eb] = tests{i, :};
        args = {'NumPackets', NP, 'StopAtZero', false, 'Receiver', "discriminator", ...
                'SamplesPerSymbol', sps, 'CFO_Hz', d.CFO_Hz, 'Intf_Type', ityp, ...
                'Intf_Offset_Hz', foff, 'Intf_CI_dB', ci};
        if isnan(wl)
            ebno = eb - d.ExtraLoss_dB;                      % relative test
        else
            wlDut = wl - d.ExtraLoss_dB;                     % loss attenuates wanted + interferers
            ebno  = wlDut + 174 - 10*log10(blePhyParams(phy).bitRate) - NF;
            args  = [args, {'WantedLevel_dBm', wlDut, 'IIP3_dBm', d.IIP3_dBm}]; %#ok<AGROW>
        end
        fprintf('%-28s ', name);
        per = blePerSim(phy, ebno, args{:});
        v = "PASS"; if per > limit, v = "FAIL"; end
        results = [results; table(string(d.Name), string(name), wl, ci, ebno, per, limit, v, ...
            'VariableNames', ["DUT","Test","Wanted_dBm","CI_dB","EbNo_dB","PER","Limit","Verdict"])]; %#ok<AGROW>
    end
end
disp(results)

fprintf('\nRegression report (PASS on Nominal -> FAIL on other DUT):\n');
tn = unique(results.Test, 'stable'); nReg = 0; regList = strings(0,1);
for dn = ["Degraded","Nonlinear"]
    for tt = tn.'
        vN = results.Verdict(results.DUT == "Nominal" & results.Test == tt);
        vD = results.Verdict(results.DUT == dn & results.Test == tt);
        if vN == "PASS" && vD == "FAIL"
            fprintf('  %s: %s\n', dn, tt); nReg = nReg + 1; regList(end+1) = dn + ": " + tt; %#ok<SAGROW>
        end
    end
end
if nReg == 0, fprintf('  none\n'); end

%% 10b. How bad can the front end get? Intermod test PER vs IIP3
% Expected IM3 level = 3*Pint - 2*IIP3 (dBm); the test fails once it gets too
% close to the -64 dBm wanted signal.
iip3Sweep = -20:-2.5:-45;
perIM = zeros(size(iip3Sweep));
fprintf('\nIntermod test vs IIP3 (wanted -64 dBm, tones -50 dBm at +3/+6 MHz):\n');
for j = 1:numel(iip3Sweep)
    fprintf('IIP3 %6.1f dBm  (IM3 ~ %6.1f dBm)  ', iip3Sweep(j), 3*(-50) - 2*iip3Sweep(j));
    perIM(j) = blePerSim("LE1M", -64 + 174 - 60 - NF, 'NumPackets', NP, 'StopAtZero', false, ...
        'Receiver', "discriminator", 'SamplesPerSymbol', 16, 'WantedLevel_dBm', -64, ...
        'IIP3_dBm', iip3Sweep(j), 'Intf_Type', "twotone", 'Intf_Offset_Hz', [3e6 6e6], 'Intf_CI_dB', -14);
end
iFail = find(perIM > limit, 1);
iip3Min = NaN; if ~isempty(iFail) && iFail > 1, iip3Min = iip3Sweep(iFail - 1); end
fprintf('Lowest IIP3 in the sweep that still passes intermod: %.1f dBm\n', iip3Min);

figure('Name','Step 10 - RX tests', 'Position', [100 100 1100 480]);
tiledlayout(1,2);
nexttile;
M = reshape(results.PER, numel(tn), numel(duts));
barh(categorical(tn, tn), M); hold on; xline(limit, '--r', '30.8%');
set(gca, 'YDir', 'reverse'); grid on; xlabel('PER'); legend([duts.Name], 'Location', 'southeast');
title('Receiver tests at spec levels, discriminator RX');
nexttile;
plot(iip3Sweep, perIM, '-o', 'LineWidth', 1.2); hold on; yline(limit, '--r', '30.8%');
xline(IIP3nom, ':', 'nominal'); xline(IIP3nom - 10, ':', 'Nonlinear DUT');
set(gca, 'XDir', 'reverse'); grid on; xlabel('IIP3 (dBm)'); ylabel('PER');
title('Intermod test (n = 3) vs front-end IIP3');
exportgraphics(gcf, 'results/figs/Step_10_-_RX_tests.png', 'Resolution', 120);
writetable(results, "results/step10_test_report.csv");
save("results/step10.mat", "results", "nReg", "regList", "IIP3nom", "tests", "duts", "NP", ...
    "iip3Sweep", "perIM", "iip3Min");
