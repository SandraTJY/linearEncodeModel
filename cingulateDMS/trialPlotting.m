R2_full_all = allResults.R2_full;
R2_threshold = 0.02;
sessName = '2025-04-23_1_MAT008'; modelName = 'Full';
% figure();
% 
% proportion_well_fit = sum(R2_full_all>R2_threshold) / numel(R2_full_all); disp(proportion_well_fit);
% % ΔR² values
% scatter(1:numel(R2_full_all), sort(R2_full_all, 'descend'), 10, 'o');
% yline(R2_threshold, '--', 'Color', [0.3 0.3 0.3]);

% Best fitted cell
neuralRef = 'cell649';
cell_fullModel = obj.crossVal.(neuralRef).full;
nFolds = size(cell_fullModel, 2);
cell_full_betas = NaN(nFolds, numel(cell_fullModel(1).Beta));
for i = 1:nFolds
    cell_full_betas(i, :) = cell_fullModel(i).Beta;
end
cell_mean_betas = mean(cell_full_betas, 1); %average across row i.e. per-fold

% get beta index
regLabels = obj.crossVal.model_details.full.regLabels;
figure();
plot((1:numel(cell_mean_betas)), cell_mean_betas);