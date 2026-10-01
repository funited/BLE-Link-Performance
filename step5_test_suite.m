%% STEP 5 - Mini automated RF-PHY test suite with regression check   (~5 min)
% What you learn:
%  - spec-style receiver tests report a PER against the 30.8% limit
%  - run the same suite on a "nominal" and a "degraded" device and diff the verdicts
%  Simplified: 3 tests, Eb/No-based (not absolute dBm levels like the real spec).
close all;
%  All tests use the discriminator receiver (tolerates CFO, see Step 3), so
%  each reference level is 2 dB above that receiver's own 30.8% point.
S  = load("results/step2_per.mat");
R3 = load("results/step3.mat");
ref1 = R3.reqDisc + 2; if isnan(ref1), ref1 = 11; end

fprintf('LE125K discriminator PER curve (for the reference level):\n');
perDiscC = blePerSim("LE125K", S.EbNo, 'Receiver', "discriminator");
reqDiscC = ebnoAtPer(S.EbNo, perDiscC, 0.308);
refc = reqDiscC + 2; if isnan(refc), refc = 13; end

duts = struct('Name', {"Nominal", "Degraded"}, ...
              'CFO_Hz', {0, 150e3}, ...          % degraded: crystal at the limit
              'ExtraLoss_dB', {0, 4});           % degraded: 4 dB worse front end

results = table();
for d = duts
    fprintf('\n=== DUT: %s ===\n', d.Name);
    results = [results; runTestSuite(d, ref1, refc)]; %#ok<AGROW>
end
disp(results)

% Regression check: tests that passed on Nominal but fail on Degraded
tests = unique(results.Test, 'stable');
fprintf('\nRegression report:\n');
nReg = 0;
for t = tests.'
    vN = results.Verdict(results.DUT == "Nominal"  & results.Test == t);
    vD = results.Verdict(results.DUT == "Degraded" & results.Test == t);
    if vN == "PASS" && vD == "FAIL"
        fprintf('  REGRESSION: %s\n', t); nReg = nReg + 1;
    end
end
if nReg == 0, fprintf('  none\n'); end

writetable(results, "results/step5_test_report.csv");
save("results/step5.mat", "results", "nReg", "ref1", "refc", "perDiscC", "reqDiscC");

%% ---- local function ----
function R = runTestSuite(dut, ref1, refc)
limit = 0.308;
names = ["LE1M sensitivity"; "LE125K sensitivity"; "LE1M co-channel C/I 21 dB"];
per = zeros(3,1);
per(1) = blePerSim("LE1M",   ref1 - dut.ExtraLoss_dB, 'CFO_Hz', dut.CFO_Hz, ...
                   'StopAtZero', false, 'Receiver', "discriminator");
per(2) = blePerSim("LE125K", refc - dut.ExtraLoss_dB, 'CFO_Hz', dut.CFO_Hz, ...
                   'StopAtZero', false, 'Receiver', "discriminator");
per(3) = blePerSim("LE1M",   20   - dut.ExtraLoss_dB, 'CFO_Hz', dut.CFO_Hz, ...
                   'CI_dB', 21, 'StopAtZero', false, 'Receiver', "discriminator");
verdict = repmat("PASS", 3, 1);
verdict(per > limit) = "FAIL";
R = table(repmat(string(dut.Name), 3, 1), names, per, repmat(limit, 3, 1), verdict, ...
    'VariableNames', ["DUT","Test","PER","Limit","Verdict"]);
end
