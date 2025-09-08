function [neuralPred, cBeta, cR, subIdx, cRidge, cLabels_sorted] = crossValModel(X, ...
    Y, cLabels, regIdx, regLabels, folds, trialVec)
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
    cLabels_sorted = regLabels(sort(find(ismember(regLabels, cLabels))));
    subIdx = regIdx(cIdx);
    temp = unique(subIdx);
    for x = 1:length(temp)
        subIdx(subIdx == temp(x)) = x;
    end
    cR = X(:, cIdx);

    % 2. Identify trials
    allTrials = unique(trialVec);
    nTrials   = max(allTrials);

    if folds > nTrials
        error('Number of folds (%d) exceeds number of trials (%d)', folds, nTrials);
    end

    % 3. Shuffle and split trial indices
    rng(1); % reproducibility
    shuffledTrials = allTrials(randperm(nTrials));
    trialFolds = cell(1, folds);
    for f = 1:folds
        trialFolds{f} = shuffledTrials(f:folds:end);
    end

    % 4. Pre-allocate
    neuralPred = zeros(size(Y), 'like', Y);
    cBeta      = cell(1, folds);
    foldPreds  = cell(1, folds); % NEW: per-fold predictions
    foldIdx    = cell(1, folds); % NEW: per-fold test indices

    % 5. Cross-validation loop
    for iFolds = 1:folds
        testTrials = trialFolds{iFolds};
        testIdx    = ismember(trialVec, testTrials);
        trainIdx   = ~testIdx;

        if iFolds == 1
            [cRidge, cBeta{iFolds}] = ridgeMML(cR(trainIdx, :), Y(trainIdx,:), [0.01, 0.1, 1, 10], true);
        else
            [~, cBeta{iFolds}] = ridgeMML(cR(trainIdx, :), Y(trainIdx,:), cRidge, true);
        end

        % Predict test set
        thisPred = (cR(testIdx, :) * cBeta{iFolds}(2:end))' + cBeta{iFolds}(1);
        neuralPred(testIdx, :) = thisPred;

        % Save fold diagnostics
        foldPreds{iFolds} = thisPred;
        foldIdx{iFolds}   = find(testIdx);

        if rem(iFolds, max(1, floor(folds/5))) == 0
            fprintf(1, 'Completed fold %d of %d\n', iFolds, folds);
        end
    end
end
