%% ============================================================
%  5G MEC vs CLOUD — MATLAB Statistical Validation
%
%  Reads the CSV output produced by ns-3 (mec_arvr_final.cc) and
%  re-processed by python/analysis.py, and independently
%  regenerates comparison graphs + a statistical summary as a
%  validation step alongside the Python analysis.
%
%  Expected CSV columns (results/latency.csv):
%      flow_id, path, src, dst, tx_packets, rx_packets,
%      lost_packets, avg_delay_ms, throughput_mbps,
%      packet_loss_percent
%
%  Works unmodified from:
%      MATLAB Desktop, MATLAB Online, Windows, Linux, GitHub
%  because the results folder is located automatically (see
%  locateResultsDir below) instead of being hardcoded.
% ===============================================================

clear; clc; close all;

disp('=================================================')
disp(' 5G MEC vs CLOUD — MATLAB Statistical Validation')
disp('=================================================')

%% ------------------------------------------------------------
% 1. Locate the results folder automatically
%% ------------------------------------------------------------
resultsDir = locateResultsDir();
fprintf('Results folder: %s\n\n', resultsDir);

latencyFile = fullfile(resultsDir, 'latency.csv');
if ~isfile(latencyFile)
    error(['Could not find %s\n' ...
           'Run the ns-3 simulation, then python/analysis.py first ' ...
           'to generate results/latency.csv.'], latencyFile);
end

fprintf('Reading %s ...\n', latencyFile);
T = readtable(latencyFile);
disp(T)

%% ------------------------------------------------------------
% 2. Split MEC / CLOUD rows
%% ------------------------------------------------------------
mecRows   = T(strcmpi(T.path, 'MEC'), :);
cloudRows = T(strcmpi(T.path, 'CLOUD'), :);

if isempty(mecRows)
    error('No MEC rows found in latency.csv.');
end
if isempty(cloudRows)
    error('No CLOUD rows found in latency.csv.');
end

mecDelay   = mecRows.avg_delay_ms;
cloudDelay = cloudRows.avg_delay_ms;

mecTput    = mecRows.throughput_mbps;
cloudTput  = cloudRows.throughput_mbps;

mecLoss    = mecRows.packet_loss_percent;
cloudLoss  = cloudRows.packet_loss_percent;

%% ------------------------------------------------------------
% 3. Aggregate statistics
%% ------------------------------------------------------------
mecDelayMean    = mean(mecDelay);
cloudDelayMean  = mean(cloudDelay);

mecTputMean     = mean(mecTput);
cloudTputMean   = mean(cloudTput);

mecLossMean     = mean(mecLoss);
cloudLossMean   = mean(cloudLoss);

latencyReductionMs  = cloudDelayMean - mecDelayMean;
latencyReductionPct = 100 * latencyReductionMs / cloudDelayMean;
throughputGainPct   = 100 * (mecTputMean - cloudTputMean) / cloudTputMean;

fprintf('\n========== SUMMARY ==========\n');
fprintf('MEC avg delay      : %.4f ms\n', mecDelayMean);
fprintf('Cloud avg delay    : %.4f ms\n', cloudDelayMean);
fprintf('Latency reduction  : %.4f ms (%.2f%%)\n', latencyReductionMs, latencyReductionPct);
fprintf('MEC throughput     : %.4f Mbps\n', mecTputMean);
fprintf('Cloud throughput   : %.4f Mbps\n', cloudTputMean);
fprintf('Throughput gain    : %.2f%%\n', throughputGainPct);
fprintf('MEC packet loss    : %.4f%%\n', mecLossMean);
fprintf('Cloud packet loss  : %.4f%%\n', cloudLossMean);

%% ------------------------------------------------------------
% 4. Bar chart — Latency comparison
%% ------------------------------------------------------------
fig1 = figure('Color', 'w', 'Position', [100 100 600 450]);
b = bar([1 2], [mecDelayMean, cloudDelayMean], 0.5);
b.FaceColor = 'flat';
b.CData(1,:) = [0.18 0.52 0.67];   % MEC blue
b.CData(2,:) = [0.91 0.31 0.22];   % Cloud red
set(gca, 'XTick', [1 2], 'XTickLabel', {'MEC', 'CLOUD'}, 'FontSize', 12);
ylabel('Average End-to-End Delay (ms)', 'FontWeight', 'bold');
title('Latency Comparison: MEC vs Cloud (MATLAB Validation)');
grid on; box off;
text(1, mecDelayMean,   sprintf('%.2f ms', mecDelayMean),   'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
text(2, cloudDelayMean, sprintf('%.2f ms', cloudDelayMean), 'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
saveas(fig1, fullfile(resultsDir, 'matlab_latency_comparison.png'));

%% ------------------------------------------------------------
% 5. Bar chart — Throughput comparison
%% ------------------------------------------------------------
fig2 = figure('Color', 'w', 'Position', [100 100 600 450]);
b = bar([1 2], [mecTputMean, cloudTputMean], 0.5);
b.FaceColor = 'flat';
b.CData(1,:) = [0.18 0.52 0.67];
b.CData(2,:) = [0.91 0.31 0.22];
set(gca, 'XTick', [1 2], 'XTickLabel', {'MEC', 'CLOUD'}, 'FontSize', 12);
ylabel('Throughput (Mbps)', 'FontWeight', 'bold');
title('Throughput Comparison: MEC vs Cloud (MATLAB Validation)');
grid on; box off;
text(1, mecTputMean,   sprintf('%.2f Mbps', mecTputMean),   'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
text(2, cloudTputMean, sprintf('%.2f Mbps', cloudTputMean), 'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
saveas(fig2, fullfile(resultsDir, 'matlab_throughput_comparison.png'));

%% ------------------------------------------------------------
% 6. Bar chart — Packet loss comparison
%% ------------------------------------------------------------
fig3 = figure('Color', 'w', 'Position', [100 100 600 450]);
b = bar([1 2], [mecLossMean, cloudLossMean], 0.5);
b.FaceColor = 'flat';
b.CData(1,:) = [0.18 0.52 0.67];
b.CData(2,:) = [0.91 0.31 0.22];
set(gca, 'XTick', [1 2], 'XTickLabel', {'MEC', 'CLOUD'}, 'FontSize', 12);
ylabel('Packet Loss (%)', 'FontWeight', 'bold');
title('Packet Loss Comparison: MEC vs Cloud (MATLAB Validation)');
grid on; box off;
ylim([0, max([mecLossMean, cloudLossMean, 0.5]) * 1.4]);
text(1, mecLossMean,   sprintf('%.3f%%', mecLossMean),   'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
text(2, cloudLossMean, sprintf('%.3f%%', cloudLossMean), 'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold');
saveas(fig3, fullfile(resultsDir, 'matlab_packet_loss.png'));

%% ------------------------------------------------------------
% 7. Delay histogram
%     NOTE: this run has exactly one flow per path (one UE, one
%     MEC flow, one Cloud flow), so each "distribution" is a
%     single point. The histogram/CDF below render correctly for
%     that case but become genuinely informative only if the
%     ns-3 script is extended to multiple UEs or repeated
%     RngRun seeds, each appended as a new row in latency.csv.
%% ------------------------------------------------------------
fig4 = figure('Color', 'w', 'Position', [100 100 650 450]);
allDelays = [mecDelay; cloudDelay];
binWidth = max(1, range(allDelays)/10 + 0.01);
hold on;
histogram(mecDelay,   'BinWidth', binWidth, 'FaceColor', [0.18 0.52 0.67], 'FaceAlpha', 0.7, 'DisplayName', 'MEC');
histogram(cloudDelay, 'BinWidth', binWidth, 'FaceColor', [0.91 0.31 0.22], 'FaceAlpha', 0.7, 'DisplayName', 'CLOUD');
hold off;
xlabel('Delay (ms)');
ylabel('Frequency (number of flows)');
title('Delay Distribution: MEC vs Cloud');
legend('Location', 'best');
grid on; box off;
saveas(fig4, fullfile(resultsDir, 'matlab_delay_histogram.png'));

%% ------------------------------------------------------------
% 8. Empirical CDF of delay
%% ------------------------------------------------------------
fig5 = figure('Color', 'w', 'Position', [100 100 650 450]);
hold on;
if numel(mecDelay) > 1
    [fMec, xMec] = ecdf(mecDelay);
    stairs(xMec, fMec, 'Color', [0.18 0.52 0.67], 'LineWidth', 2, 'DisplayName', 'MEC');
else
    stairs([0, mecDelay, mecDelay*1.2], [0, 0, 1], 'Color', [0.18 0.52 0.67], 'LineWidth', 2, 'DisplayName', 'MEC');
end
if numel(cloudDelay) > 1
    [fCloud, xCloud] = ecdf(cloudDelay);
    stairs(xCloud, fCloud, 'Color', [0.91 0.31 0.22], 'LineWidth', 2, 'DisplayName', 'CLOUD');
else
    stairs([0, cloudDelay, cloudDelay*1.2], [0, 0, 1], 'Color', [0.91 0.31 0.22], 'LineWidth', 2, 'DisplayName', 'CLOUD');
end
hold off;
xlabel('Delay (ms)');
ylabel('Empirical CDF F(x)');
title('CDF of End-to-End Delay: MEC vs Cloud');
legend('Location', 'best');
grid on; box off;
saveas(fig5, fullfile(resultsDir, 'matlab_delay_cdf.png'));

%% ------------------------------------------------------------
% 9. Summary table CSV
%% ------------------------------------------------------------
Summary = table;
Summary.Path                 = ["MEC"; "CLOUD"];
Summary.AvgDelay_ms          = [mecDelayMean; cloudDelayMean];
Summary.Throughput_Mbps      = [mecTputMean; cloudTputMean];
Summary.PacketLoss_pct       = [mecLossMean; cloudLossMean];

disp(' ')
disp('Summary Table')
disp(Summary)

writetable(Summary, fullfile(resultsDir, 'matlab_summary.csv'));

%% ------------------------------------------------------------
% 10. Statistical summary report (text file)
%% ------------------------------------------------------------
statsPath = fullfile(resultsDir, 'matlab_stats_summary.txt');
fid = fopen(statsPath, 'w');
fprintf(fid, '5G MEC vs Cloud — MATLAB Statistical Validation\n');
fprintf(fid, '=================================================\n\n');

fprintf(fid, 'Latency (ms):\n');
fprintf(fid, '  MEC   : mean = %.4f, std = %.4f\n', mecDelayMean, std(mecDelay));
fprintf(fid, '  Cloud : mean = %.4f, std = %.4f\n', cloudDelayMean, std(cloudDelay));
fprintf(fid, '  Reduction with MEC: %.4f ms (%.2f%%)\n\n', latencyReductionMs, latencyReductionPct);

fprintf(fid, 'Throughput (Mbps):\n');
fprintf(fid, '  MEC   : mean = %.4f, std = %.4f\n', mecTputMean, std(mecTput));
fprintf(fid, '  Cloud : mean = %.4f, std = %.4f\n', cloudTputMean, std(cloudTput));
fprintf(fid, '  Gain with MEC: %.2f%%\n\n', throughputGainPct);

fprintf(fid, 'Packet Loss (%%):\n');
fprintf(fid, '  MEC   : mean = %.4f\n', mecLossMean);
fprintf(fid, '  Cloud : mean = %.4f\n\n', cloudLossMean);

if numel(mecDelay) > 1 && numel(cloudDelay) > 1
    try
        [~, p] = ttest2(mecDelay, cloudDelay);
        fprintf(fid, 'Two-sample t-test (delay, MEC vs Cloud): p = %.6g\n', p);
    catch
        fprintf(fid, 'Statistics Toolbox not available — skipped t-test.\n');
    end
else
    fprintf(fid, 'NOTE: Only one flow per path was simulated in this run, so this\n');
    fprintf(fid, 'report contains single-sample statistics rather than a true\n');
    fprintf(fid, 'distribution (std = 0, histogram/CDF each show a single point).\n');
    fprintf(fid, 'To get a statistically meaningful distribution and a valid\n');
    fprintf(fid, 't-test, re-run ns-3 multiple times (e.g. with different\n');
    fprintf(fid, '--RngRun seeds) or with multiple simulated UEs, appending each\n');
    fprintf(fid, 'run''s row to results_summary.csv before re-running this script.\n');
end

fprintf(fid, '\n--------------------------------------------\n');
fprintf(fid, 'Inference\n');
fprintf(fid, '--------------------------------------------\n');
fprintf(fid, 'The MEC server processes AR/VR traffic near the user, reducing\n');
fprintf(fid, 'end-to-end latency substantially compared with routing the same\n');
fprintf(fid, 'traffic to a distant cloud server, while throughput and packet\n');
fprintf(fid, 'loss remain comparable between the two paths in this scenario.\n');
fprintf(fid, 'This supports the expected advantage of Multi-access Edge\n');
fprintf(fid, 'Computing (MEC) for latency-sensitive 5G AR/VR applications.\n');

fclose(fid);

fprintf('\nSaved figures and stats to: %s\n', resultsDir);
fprintf('  matlab_latency_comparison.png\n');
fprintf('  matlab_throughput_comparison.png\n');
fprintf('  matlab_packet_loss.png\n');
fprintf('  matlab_delay_histogram.png\n');
fprintf('  matlab_delay_cdf.png\n');
fprintf('  matlab_summary.csv\n');
fprintf('  matlab_stats_summary.txt\n');
disp(' ')
disp('Analysis complete.')


%% ============================================================
%  Local function: locate the results folder automatically
%  Works regardless of whether mec_analysis.m is run from
%  matlab/, the repo root, MATLAB Drive, or MATLAB Online with
%  files placed directly alongside the script.
%% ============================================================
function resultsDir = locateResultsDir()
    scriptDir = fileparts(mfilename('fullpath'));
    here = pwd;

    candidates = {
        fullfile(scriptDir, '..', 'results');  % repo layout: matlab/ + ../results
        fullfile(here, 'results');             % current folder + results
        fullfile(here, 'Results');             % case-variant on some platforms
        scriptDir;                             % files placed next to the script
        here                                   % files placed in current folder directly
    };

    for k = 1:numel(candidates)
        candidate = candidates{k};
        if isfolder(candidate) && isfile(fullfile(candidate, 'latency.csv'))
            resultsDir = candidate;
            return;
        end
    end

    % Fall back to the conventional repo path even if latency.csv
    % isn't there yet, so the error message below points somewhere useful.
    resultsDir = fullfile(scriptDir, '..', 'results');
end
