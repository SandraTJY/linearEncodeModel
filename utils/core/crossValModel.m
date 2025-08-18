function [neuralPred, cBeta, cR, subIdx, cRidge, cLabels_sorted] = crossValModel(X, Y, cLabels, regIdx, regLabels, folds, trialVec)
    % crossValModel: Performs trial-based cross-validated R² prediction.
    
    % INPUTS:
    % - X:            [T x R] Full design matrix (T = time, R = regressors)
    % - Y:            [C x T] Neural signal (C = components)
    % - cLabels:      Cell array of labels to include (e.g. task regressors)
    % - regIdx:       Vector assigning each regressor column a group label
    % - regLabels:    Cell array of all regressor labels
    % - folds:        Number of CV folds
    % - trialVec:     [T x 1] Trial number for each row (after zero-row removal)
    
    % OUTPUTS:
    % - fluorPred:    Predicted fluorescence
    % - cBeta:        Cell array of beta weights per fold
    % - cR:           Reduced design matrix with only selected regressors
    % - subIdx:       New regressor group indices for selected subset
    % - cRidge:       Ridge regularisation penalty used
    % - cLabels:      Confirmed regressor labels used

% 1. Get regressors matching the desired labels
cIdx = ismember(regIdx, find(ismember(regLabels, cLabels)));
cLabels_sorted = regLabels(sort(find(ismember(regLabels, cLabels)))); % Sorted in order

subIdx = regIdx(cIdx); % Get regressor index corresponding to the larger, full design matrix (input)
temp = unique(subIdx); % Get the unique index number
for x = 1:length(temp)
    subIdx(subIdx == temp(x)) = x; % Reindexes the regressors: e.g., [3,3,7,7,10],to [1,1,2,2,3]
end

cR = X(:, cIdx);  % Reduced regressor matrix to selected regressors

% 2. Identify trials (time kernel)
allTrials = unique(trialVec); % Get the total number of trials
nTrials = max(allTrials); % Number of trials in the session

if folds > nTrials % Sanity check: can’t split into more folds than the number of trials.
    error('Number of folds (%d) exceeds number of trials (%d)', folds, nTrials);
end

% 3. Shuffle and split trial indices
rng(1);  % Reproducibility
shuffledTrials = allTrials(randperm(nTrials)); % Shuffle trials randomly, using a fixed seed (so results are reproducible).
trialFolds = cell(1, folds); % Initialise container

for f = 1:folds
    trialFolds{f} = shuffledTrials(f:folds:end); % trial 1 goes to fold 1, trial 2 to fold 2, etc., then wraps around
end

% 4. Pre-allocate
neuralPred = zeros(size(Y), 'like', Y); % Initialise empty container for output
cBeta = cell(1, folds); % Initialise empty container for output

% 5. Cross-validation loop
for iFolds = 1:folds
    % Identify training and test indices based on trial numbers
    testTrials = trialFolds{iFolds};
    testIdx = ismember(trialVec, testTrials);
    trainIdx = ~testIdx;

    % Ridge regression
    if iFolds == 1
        [cRidge, cBeta{iFolds}] = ridgeMML(cR(trainIdx, :), Y(trainIdx,:), true);
    else
        [~, cBeta{iFolds}] = ridgeMML(cR(trainIdx, :), Y(trainIdx, :), true, cRidge);
    end

    % Predict test set
    neuralPred(testIdx, :) = (cR(testIdx, :) * cBeta{iFolds}(2:end))' + cBeta{iFolds}(1); % Remove the intercept from beta before prediction

    % Optional progress message
    if rem(iFolds, max(1, floor(folds/5))) == 0
        fprintf(1, 'Completed fold %d of %d\n', iFolds, folds);
    end
end
end