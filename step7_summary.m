%% STEP 7 - One summary of every headline number   (instant)
r1 = load("results/step1.mat");
r2 = load("results/step2_per.mat");
r3 = load("results/step3.mat");
r4 = load("results/step4.mat");
r5 = load("results/step5.mat");
r6 = load("results/step6.mat");

fprintf('\n================ BLE DEMO SUMMARY (SIMULATED, quick run) ================\n');
fprintf('Packets per Eb/No point: %d   Noise figure assumed: %d dB\n\n', r2.NP, r2.NF);

fprintf('Waveforms (Step 1)\n');
disp(r1.T1)
fprintf('Hops into Wi-Fi ch 6 band: no AFH %d/%d, AFH %d/%d\n\n', ...
    r1.hitsAll, r1.nEvents, r1.hitsAFH, r1.nEvents);

fprintf('PER and sensitivity (Step 2)\n');
disp(r2.T2)

fprintf('CFO impact, LE1M (Step 3)\n');
fprintf('Ideal coherent RX (no CFO tracking) fails from %.1f kHz CFO\n', r3.breakRaw_kHz);
fprintf('Discriminator RX needs %.1f dB Eb/No at 30.8%% PER (ideal: %.1f dB); CFO sweep at %.1f dB:\n', ...
    r3.reqDisc, r2.req(r2.phys == "LE1M"), r3.EbNoDisc);
disp(r3.T3)

fprintf('Link budget at Ptx %d dBm, n = %g (Step 4)\n', r4.Ptx, r4.n);
disp(r4.T4)
disp(r4.T4b)
fprintf('LE2M beats LE125K on throughput over %.0f%% of the toy floor plan\n\n', r4.frac2Mwins);

fprintf('Test suite (Step 5)\n');
disp(r5.results)
fprintf('Regressions caught: %d\n\n', r5.nReg);

fprintf('Coexistence (Step 6)\n');
fprintf('LE1M average PER with Wi-Fi ch 6: no AFH %.1f%%  ->  AFH %.1f%%\n', ...
    100*r6.perNoAFH, 100*r6.perAFH);
fprintf('==========================================================================\n');
