%% plot_vidDeconv_crossVal
% *plot_vidDeconv_crossVal*
% This script plots model comparison results from obj.crossVal
% It reads model names directly from the data, no hardcoding

%% 1) Prepare data across sessions
allDeltaR2  = [];
allFullR2   = [];
allLabels   = {}; % store session+cell labels

sessionFields = fieldnames(allObjs);  % get all field names

for iObj = 1:numel(sessionFields)
    sessName = sessionFields{iObj};
    obj = allObjs.(sessName); 
    
    if ~isfield(obj, 'crossVal') || isempty(obj.crossVal)
        warning('Skipping session %s: missing or empty crossVal.', sessName);
        continue;
    end
    
    %% --- Loop over all model fields (cell0, cell1, etc.) ---
    modelFields = fieldnames(obj.crossVal);
    
    for m = 1:numel(modelFields)
        modelName = modelFields{m};
        modelStruct = obj.crossVal.(modelName);
        
        %% --- Full model R2 ---
        if isfield(modelStruct, 'full') && isfield(modelStruct.full, 'R2')
            R2_full  = modelStruct.full.R2;
        else
            R2_full  = NaN;
        end
        
        allFullR2  = [allFullR2; R2_full];
        allLabels  = [allLabels; {sprintf('%s_%s', sessName, modelName)}];
        
        %% --- Subset model DeltaR2 ---
        if isfield(modelStruct, 'subset')
            subsetGroups = fieldnames(modelStruct.subset);
            deltaR2  = NaN(1, numel(subsetGroups));
            
            for s = 1:numel(subsetGroups)
                subName = subsetGroups{s};
                if isfield(modelStruct.subset.(subName), 'DeltaR2')
                    deltaR2(s)  = modelStruct.subset.(subName).DeltaR2;
                end
            end
            
            allDeltaR2  = [allDeltaR2; deltaR2];
            
            %% --- (NEW) Per-neuron plot ---
            figure;
            plot(1:numel(subsetGroups), deltaR2, '-o', 'LineWidth', 2);
            yline(0, '--', 'Color', [0.2 0.2 0.2]);
            
            xticks(1:numel(subsetGroups));
            xticklabels(subsetGroups);
            xtickangle(45);
            ylabel('\DeltaR^2 / R^2_{full}', 'FontSize', 12);
            titleStr = sprintf('%s - %s (R^2_{full}=%.3f)', sessName, modelName, R2_full);
            
            % Flag bad fits
            if R2_full < 0.01
                title(titleStr, 'Color', 'r'); % red flag
            else
                title(titleStr);
            end
            
            grid on;
            
            % Save figure
            saveas(gcf, sprintf('singleNeuron_%s_%s.png', sessName, modelName));
            close(gcf);
        end
    end
end

%% 2) Determine dynamic model names
allModelNames_full   = {};
allModelNames_subset = {};

for iObj = 1:numel(sessionFields)
    sessName = sessionFields{iObj};
    obj = allObjs.(sessName);

    if ~isfield(obj, 'crossVal') || isempty(obj.crossVal)
        continue;
    end

    modelFields = fieldnames(obj.crossVal);

    for m = 1:numel(modelFields)
        modelName = modelFields{m};
        modelStruct = obj.crossVal.(modelName);

        % ---- Collect full model names ----
        if isfield(modelStruct, 'full')
            allModelNames_full = [allModelNames_full, {modelName}];
        end

        % ---- Collect subset model names ----
        if isfield(modelStruct, 'subset')
            subsetGroups = fieldnames(modelStruct.subset);
            allModelNames_subset = union(allModelNames_subset, subsetGroups, 'stable');
        end
    end
end

modelNames_full   = allModelNames_full;
modelNames_subset = allModelNames_subset;

%% 3) Aggregate Plot Across All Neurons
figure; hold on;

numModels = numel(modelNames_subset);

% Plot individual neurons (light grey)
if ~isempty(allDeltaR2)
    plot(1:numModels, allDeltaR2', '-', 'Color', [0.6 0.6 0.6 0.3], 'LineWidth', 1);
end

% Compute and plot mean (dark black line)
meanDelta = mean(allDeltaR2, 1, 'omitnan');
plot(1:numModels, meanDelta, '-k', 'LineWidth', 3);

% Reference line
yline(0, '--', 'LineWidth', 1.2, 'Color', [0.2 0.2 0.2]);

% Axis formatting
xticks(1:numModels);
xticklabels(modelNames_subset);
xtickangle(45);
ylabel('\DeltaR^2 / R^2_{full}', 'FontSize', 14);
title('Model Contribution Comparison: Task Components');
ylim([-1, 320]);
xlim([0.8, numModels + 0.2]);
grid on;
