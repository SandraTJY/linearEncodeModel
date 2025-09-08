%% plot_vidDeconv_crossVal_withSummary
% This script plots model comparison results from obj.crossVal
% and annotates with neuralEventSummary (significant events per neuron).

%% 0) Load summary table (replace with actual load if in a file)
% neuralEventSummary is assumed to be a MATLAB table with columns:
%   Session | Cell | NumSignificant | SignificantEvents
% Example entry:
%   "session_2024_09_11_2_JM013" "cell0" 3 "stimulusOnsetTime,choiceStartTime,rewardTime"
% If you have it as text, convert to table first.

% Example (dummy):
neuralEventSummary = readtable('neuralEventSummary.csv', ...
    'Delimiter', ',', 'ReadVariableNames', true);

%% 1) Prepare output folder
outDir = fullfile(pwd, 'NeuronPlots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 2) Iterate over sessions and neurons
sessionFields = fieldnames(allObjs_vid);

for iObj = 1:numel(sessionFields)
    sessName = sessionFields{iObj};
    obj = allObjs_vid.(sessName);

    if ~isfield(obj, 'crossVal') || isempty(obj.crossVal)
        warning('Skipping session %s: missing or empty crossVal.', sessName);
        continue;
    end

    % Loop over all neurons (cell0, cell1, …)
    modelFields = fieldnames(obj.crossVal);

    for m = 1:numel(modelFields)
        modelName   = modelFields{m}; % e.g. "cell0"
        modelStruct = obj.crossVal.(modelName);

        % --- Full model R² ---
        if isfield(modelStruct, 'full') && isfield(modelStruct.full, 'R2')
            R2_full = modelStruct.full.R2;
        else
            R2_full = NaN;
        end

        % --- Subset ΔR² ---
        deltaR2 = [];
        subsetGroups = {};
        if isfield(modelStruct, 'subset')
            subsetGroups = fieldnames(modelStruct.subset);
            deltaR2 = NaN(1, numel(subsetGroups));
            for s = 1:numel(subsetGroups)
                subName = subsetGroups{s};
                if isfield(modelStruct.subset.(subName), 'DeltaR2')
                    deltaR2(s) = modelStruct.subset.(subName).DeltaR2;
                end
            end
        end

        % --- Cross-reference with neuralEventSummary ---
        idx = strcmp(neuralEventSummary.Session, sessName) & ...
              strcmp(neuralEventSummary.Cell, modelName);
        if any(idx)
            sigEvents = neuralEventSummary.SignificantEvents{idx};
            numSig    = neuralEventSummary.NumSignificant(idx);
        else
            sigEvents = '';
            numSig    = 0;
        end

        %% ---- Plot per-neuron results ----
        fig = figure('Name', sprintf('%s - %s', sessName, modelName), ...
                     'NumberTitle','off', 'Visible','off');
        hold on;

        % ΔR² values
        plot(1:numel(deltaR2), deltaR2, '-o', 'LineWidth', 2);
        yline(0, '--', 'Color', [0.3 0.3 0.3]);

        % Format
        xticks(1:numel(deltaR2));
        xticklabels(subsetGroups);
        xtickangle(45);
        ylabel('\DeltaR^2', 'FontSize', 12);

        % Title with R² and significant events
        titleStr = sprintf('Neuron: %s | Session: %s | Full R^2 = %.2f | SigEvents: %d', ...
                           modelName, sessName, R2_full, numSig);
        title(titleStr, 'Interpreter','none');

        % Annotate events if present
        if numSig > 0
            text(1, max(deltaR2)*0.9, sprintf('Events: %s', sigEvents), ...
                'Interpreter','none', 'FontSize', 10, 'Color','b');
        end

        % Flag poor fits
        if R2_full < 0.05
            sgtitle(sprintf('⚠️ Bad Fit: %s - %s', sessName, modelName), 'Color','r');
        end

        grid on;

        % Save figure
        saveas(fig, fullfile(outDir, sprintf('%s_%s.png', sessName, modelName)));
        close(fig);
    end
end

%% 3) Summary across clusters (append after neuron plots)
clusterVals = 0:3;  % 4 clusters
clusterDir = fullfile(outDir, 'ClusterPlots_NumSig');
if ~exist(clusterDir,'dir'), mkdir(clusterDir); end

for c = clusterVals
    fprintf('Cluster %d...\n', c);

    % Find neurons in this cluster
    thisIdx = neuralEventSummary.NumSignificant == c;
    if ~any(thisIdx), continue; end

    % --- First pass: collect all subset group names ---
    allGroups = {};
    for i = find(thisIdx)'
        sessName  = neuralEventSummary.Session{i};
        modelName = neuralEventSummary.Cell{i};
        if ~isfield(allObjs_vid, sessName), continue; end
        if ~isfield(allObjs_vid.(sessName).crossVal, modelName), continue; end
        modelStruct = allObjs_vid.(sessName).crossVal.(modelName);
        if isfield(modelStruct, 'subset')
            allGroups = union(allGroups, fieldnames(modelStruct.subset));
        end
    end

   % --- Second pass: collect ΔR² aligned to allGroups ---
    allDelta = NaN(sum(thisIdx), numel(allGroups));
    neuronIdx = 0;
    for i = find(thisIdx)'
        neuronIdx = neuronIdx + 1;
        sessName  = neuralEventSummary.Session{i};
        modelName = neuralEventSummary.Cell{i};
        if ~isfield(allObjs_vid, sessName), continue; end
        if ~isfield(allObjs_vid.(sessName).crossVal, modelName), continue; end
        modelStruct = allObjs_vid.(sessName).crossVal.(modelName);
    
        if isfield(modelStruct, 'subset')
            neuronGroups = fieldnames(modelStruct.subset);  % neuron-specific groups
            for ng = 1:numel(neuronGroups)
                grpName = neuronGroups{ng};
                colIdx = find(strcmp(allGroups, grpName));  % match to allGroups
                if isempty(colIdx), continue; end
                if isfield(modelStruct.subset.(grpName), 'DeltaR2')
                    allDelta(neuronIdx, colIdx) = modelStruct.subset.(grpName).DeltaR2;
                end
            end
        end
    end

    % --- Plot ---
    fig = figure('Name', sprintf('Cluster %d sig events', c), ...
                 'NumberTitle','off','Visible','on'); hold on;

    % Individual neurons in grey
    plot(1:size(allDelta,2), allDelta', 'Color', [0.7 0.7 0.7]);

    % Mean ± SEM
    m = mean(allDelta, 1, 'omitnan');
    s = std(allDelta, [], 1, 'omitnan') ./ sqrt(sum(~isnan(allDelta)));
    errorbar(1:numel(m), m, s, 'k-', 'LineWidth', 2, ...
             'CapSize', 10, 'Marker','o','MarkerFaceColor','k');

    % Formatting
    xticks(1:numel(allGroups));
    xticklabels(allGroups);
    xtickangle(45);
    ylabel('\DeltaR^2');
    title(sprintf('Cluster %d sig events (n=%d neurons)', c, size(allDelta,1)), ...
          'Interpreter','none');
    yline(0,'--','Color',[0.3 0.3 0.3]);
    grid on;

    % Save
    saveas(fig, fullfile(clusterDir, sprintf('Cluster_NumSig_%d.png', c)));
    close(fig);
end

%% 4) Bad fit count
badFitIdx = allResults.R2_full < R2_threshold;
fprintf('Total neurons: %d\n', height(allResults));
fprintf('Bad fits (<%.2f): %d (%.1f%%)\n', R2_threshold, sum(badFitIdx), ...
    100*mean(badFitIdx));

%% 5) Distributions of ΔR² by group
% Flatten out the {Groups} cell arrays into rows
flatGroups = {};
flatDeltaR2 = [];
for i = 1:height(allResults)
    groups = allResults.Groups{i};
    deltas = allResults.DeltaR2{i};
    for g = 1:numel(groups)
        flatGroups{end+1,1} = groups{g};
        flatDeltaR2(end+1,1) = deltas(g);
    end
end
summaryTbl = table(flatGroups, flatDeltaR2, ...
    'VariableNames', {'Group','DeltaR2'});
