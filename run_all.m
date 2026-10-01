%% RUN_ALL - runs the whole BLE demo in order (~20 min total, machine dependent)
% Run from inside the demo folder. Each step can also be run on its own, but
% steps 3-7 need results/step2_per.mat, step 5 needs step 3, step 10 needs
% step 5, and step 12 needs step 8.
tAll = tic;
fprintf('\n##### STEP 1 #####\n'); step1_waveforms_hopping
fprintf('\n##### STEP 2 #####\n'); step2_per_sweep
fprintf('\n##### STEP 3 #####\n'); step3_impairments
fprintf('\n##### STEP 4 #####\n'); step4_link_budget_coverage
fprintf('\n##### STEP 5 #####\n'); step5_test_suite
fprintf('\n##### STEP 6 #####\n'); step6_coexistence
fprintf('\n##### STEP 7 #####\n'); step7_summary
fprintf('\n##### STEP 8 #####\n'); step8_multipath
fprintf('\n##### STEP 9 #####\n'); step9_impairments
fprintf('\n##### STEP 10 #####\n'); step10_rx_tests
fprintf('\n##### STEP 11 #####\n'); step11_tx_tests
fprintf('\n##### STEP 12 #####\n'); step12_raytrace_coverage
fprintf('\n##### STEP 13 #####\n'); step13_coexistence
fprintf('\nTotal time: %.1f min\n', toc(tAll)/60);
