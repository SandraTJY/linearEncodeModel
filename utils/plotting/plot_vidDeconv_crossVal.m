%% plot_vidDeconv_crossVal
% *plot_vidDeconv_crossVal*
% This script plots model comparison results from obj.crossVal
% It reads model names directly from the data, no hardcoding

%% 1) Prepare data across sessions
allDeltaR2_DA  = [];
allDeltaR2_ACh = [];
allFullR2_DA   = [];
allFullR2_ACh  = [];

for iObj = 1:numel(allObjs)
    obj = allObjs{iObj};
    
    if ~isfield(obj, 'crossVal') || isempty(obj.crossVal)
        continue;
    end
    
    %% --- Full model fields ---
    fullFields = fieldnames(obj.crossVal.full);
    
    % Extract R2 for each full model
    R2_full_DA  = zeros(1, numel(fullFields));
    R2_full_ACh = zeros(1, numel(fullFields));
    
    for f = 1:numel(fullFields)
        fld = fullFields{f};
        if isfield(obj.crossVal.full.(fld), 'fullR2')
            R2_full_DA(f)  = obj.crossVal.full.(fld).fullR2;   % adjust if separate DA/ACh fields exist
            R2_full_ACh(f) = obj.crossVal.full.(fld).fullR2;
        else
            R2_full_DA(f)  = NaN;
            R2_full_ACh(f) = NaN;
        end
    end
    
    allFullR2_DA  = [allFullR2_DA; R2_full_DA];
    allFullR2_ACh = [allFullR2_ACh; R2_full_ACh];
    
    %% --- Subset model fields ---
    subsetGroups = fieldnames(obj.crossVal.subset);
    
    % Preallocate
    deltaR2_DA  = NaN(1, numel(subsetGroups));
    deltaR2_ACh = NaN(1, numel(subsetGroups));
    
    for s = 1:numel(subsetGroups)
        fld = subsetGroups{s};
        if isfield(obj.crossVal.subset.(fld), 'DeltaR2')
            deltaR2_DA(s)  = obj.crossVal.subset.(fld).DeltaR2;
            deltaR2_ACh(s) = obj.crossVal.subset.(fld).DeltaR2; % adjust if separate DA/ACh fields exist
        end
    end
    
    allDeltaR2_DA  = [allDeltaR2_DA; deltaR2_DA];
    allDeltaR2_ACh = [allDeltaR2_ACh; deltaR2_ACh];
end

%% 2) Determine dynamic model names
modelNames_full   = fullFields;
modelNames_subset = subsetGroups;

%% 3) Plot Task Components (Subset DeltaR2)
figure;
hold on;
plot(1:numel(modelNames_subset), allDeltaR2_DA', '-', 'Color', [0.6 0.6 0.6 0.3], 'LineWidth', 1);
meanDelta = mean(allDeltaR2_DA, 1, 'omitnan');
semDelta  = std(allDeltaR2_DA, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(allDeltaR2_DA),1));
errorbar(1:numel(modelNames_subset), meanDelta, semDelta, '-ko', 'LineWidth', 2.5, 'MarkerSize',7, 'MarkerFaceColor','k','CapSize',8);
yline(0,'--','LineWidth',1.2,'Color',[0.2 0.2 0.2]);
xticks(1:numel(modelNames_subset)); xticklabels(modelNames_subset); xtickangle(45);
ylabel('\DeltaR^2 / R^2_{full}', 'FontSize', 14); title('DA - Task Components', 'FontSize', 16);
ylim([-0.9,0.15]); xlim([0.8, numel(modelNames_subset)+0.2]); grid on;

sgtitle('Model Contribution Comparison: Task Components', 'FontSize', 18);
