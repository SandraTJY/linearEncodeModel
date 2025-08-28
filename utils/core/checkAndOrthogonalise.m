function [fullR_ortho, regIdx] = checkAndOrthogonalise( ...
    fullRExpand, taskLabels, vidLabels, trialLabels, taskIdx, vidIdx, trialIdx, corrThresh)
% *checkAndOrthogonalise*: Check for rank deficiency and high correlation
% between regressor groups (stim, video, trial) after expansion.
% Orthogonalise in the following order:
% 1) within task event regressors
% 2) within movement regressors
% 3) within trial regressor regressors (e.g., previous trial history)
% 4) movement w.r.t stimulus
% 5) trial w.r.t task + movement
% if necessary (e.g., high correlation or have linearly dependent columns)

% NOTE: linear dependency is likely to happen when regression combines both binary and continuous variables together. 
% If linear dependency is detected, this function adds a small jitter to
% the design matrix and rerun the QR decomposition test. If it returns as
% linear dependent again, it is likely due to a strutural issue in linear
% dependency, rather than numerical instability

% INPUTS:
% - *fullRExpand*: time-lagged, expanded design matrix [frames x regressors]
% - *taskLabels*, *vidLabels*, *trialLabels*: cell arrays of task event, video, and trial labelled names
% - *taskIdx*, *vidIdx*, *trialIdx*: column indices of the expanded taskMat, vidMat and trialMat of each regressor
% according to the labels in taskLabels
% - *corrThresh*: (optional) correlation threshold set, if it goes beyond the threshold,
% the function will pick up relevant columns from the regressor groups and orthogonalise them.
% Otherwise, if not provided, it is set as 0.95

% OUTPUTS:
% - *fullR_ortho*: orthogonalised version of fullR_out
% - *regIdx*: a vector regressor indices showing which expanded columns
% correspond to which regLabels

if nargin < 8
    corrThresh = 0.95;
end

fullR_ortho = fullRExpand;

% Combine labels for indexing
regLabels = [taskLabels, vidLabels, trialLabels];

% Define regIdx
regIdx = [];
offset = 0;

if ~isempty(taskIdx)
    regIdx = [regIdx; taskIdx + offset];
    offset = offset + max(taskIdx);  % increment offset for next group
end

if ~isempty(vidIdx)
    regIdx = [regIdx; vidIdx + offset];
    offset = offset + max(vidIdx);
end

if ~isempty(trialIdx)
    regIdx = [regIdx; trialIdx + offset];
end

% Initialise blocks
taskBlock  = [];
vidBlock   = [];
trialBlock = [];

nTaskCols = size(taskIdx, 1);   % expanded number of task columns
nVidCols  = numel(vidIdx);      % number of video columns
nTrialCols = numel(trialIdx);   % number of trial columns

if ~isempty(taskLabels)
    taskBlock = fullR_ortho(:, 1:nTaskCols);
end

if ~isempty(vidLabels)
    vidCols  = (nTaskCols + 1) : (nTaskCols + nVidCols);
    vidBlock = fullR_ortho(:, vidCols);
end

if ~isempty(trialLabels)
    trialCols   = (nTaskCols + nVidCols + 1) : (nTaskCols + nVidCols + nTrialCols);
    trialBlock  = fullR_ortho(:, trialCols);
end

%% Step 1: Within-group correlation check and orthogonalisation
% Task
if ~isempty(taskBlock) && size(taskBlock, 2) > 1
    Rtask = corr(taskBlock);
    highCorr = abs(Rtask - diag(diag(Rtask))) > corrThresh;
    if any(highCorr(:))
        fprintf('High correlation detected within TASK regressors. Orthogonalising...\n');
        [Q, ~] = qr(taskBlock, 0);
        taskBlock = Q;
        fullR_ortho(:, taskIdx) = taskBlock;
    else
        fprintf('No high correlation detected within TASK regressors...\n');
    end
else
    fprintf('TASK group is not provided or has a single regressor, skipping...\n');
end

% Video
if ~isempty(vidBlock) && size(vidBlock, 2) > 1
    Rvid = corr(vidBlock);
    highCorr = abs(Rvid - diag(diag(Rvid))) > corrThresh;
    if any(highCorr(:))
        fprintf('High correlation detected within VIDEO regressors. Orthogonalising...\n');
        [Q, ~] = qr(vidBlock, 0);
        vidBlock = Q;
        fullR_ortho(:, vidCols) = vidBlock;
    else
        fprintf('No high correlation detected within VIDEO regressors...\n');
    end
else
    fprintf('VIDEO group is not provided or has a single regressor, skipping...\n');
end

% Trial
if ~isempty(trialBlock) && size(trialBlock, 2) > 1
    Rtrial = corr(trialBlock);
    highCorr = abs(Rtrial - diag(diag(Rtrial))) > corrThresh;
    if any(highCorr(:))
        fprintf('High correlation detected within TRIAL regressors. Orthogonalising...\n');
        [Q, ~] = qr(trialBlock, 0);
        trialBlock = Q;
        fullR_ortho(:, trialCols) = trialBlock;
    else
        fprintf('No high correlation detected within TRIAL regressors...\n');
    end
else
    fprintf('TRIAL group is not provided or has a single regressor, skipping...\n');
end

%% Step 2: Cross-group correlation diagnostics
crossCorrTaskVidFlag   = ~isempty(taskBlock) && ~isempty(vidBlock) && any(any(abs(corr(taskBlock, vidBlock)) > corrThresh));
crossCorrTaskTrialFlag = ~isempty(taskBlock) && ~isempty(trialBlock) && any(any(abs(corr(taskBlock, trialBlock)) > corrThresh));
crossCorrVidTrialFlag  = ~isempty(vidBlock) && ~isempty(trialBlock) && any(any(abs(corr(vidBlock, trialBlock)) > corrThresh));

% Display diagnostic messages
if crossCorrTaskVidFlag
    fprintf('High correlation detected between TASK and VIDEO regressors.\n');
else
    fprintf('No high correlation detected between TASK and VIDEO regressors.\n');
end

if crossCorrTaskTrialFlag
    fprintf('High correlation detected between TASK and TRIAL regressors.\n');
else
    fprintf('No high correlation detected between TASK and TRIAL regressors.\n');
end

if crossCorrVidTrialFlag
    fprintf('High correlation detected between VIDEO and TRIAL regressors.\n');
else
    fprintf('No high correlation detected between VIDEO and TRIAL regressors.\n');
end

%% Step 3: Rank deficiency across all provided groups
smallR = [taskBlock, vidBlock, trialBlock];
if ~isempty(smallR)
    [~, R, ~] = qr(smallR, 0);
    tol = max(size(smallR)) * eps(norm(R, 'fro'));
    r_before = sum(abs(diag(R)) > tol);
    rankDeficient = r_before < size(smallR, 2);

    if rankDeficient
        warning('Rank deficiency detected: %d dependent column(s). Adding a small jitter to check whether it is due to numerical instability or possible linear dependency ...', ...
            size(smallR,2) - r_before);
       
        % Add small jitter if rankDeficient == true
        epsilon = eps(norm(smallR, 'fro'));
        smallR_jitter = smallR + epsilon * randn(size(smallR));

         % Check for linear dependency again
        [~, R, E] = qr(smallR_jitter, 0);
        tol = max(size(smallR_jitter)) * eps(norm(R, 'fro'));
        r_after = sum(abs(diag(R)) > tol);
        rankDeficient_jitter = r_after < size(smallR_jitter, 2);

        fprintf('Original rank: %d of %d columns.\n', r_before, size(smallR,2));
        fprintf('Rank after jitter: %d of %d columns.\n', r_after, size(smallR,2));
        
        if rankDeficient_jitter
            warning('Rank deficiency after jitter is detected: %d dependent column(s). These would not be orthogonalised as it might be theoretically relevant to your study, but please check before proceeding ...', ...
                size(smallR_jitter,2) - r_after);
            depCols = sort(E(r_after+1:end));
            disp('Linearly dependent regressors:');
            disp(regLabels(regIdx(depCols))');
        else
            fprintf('Rank deficiency resolved after jitter — likely numerical precision issue.\n');
        end
    else
        fprintf('No linear dependency detected across provided regressor groups.\n');
    end
else
    fprintf('No regressors provided for rank check.\n');
end

%% Step 4: Orthogonalisation across groups if needed
% Video w.r.t Task
if crossCorrTaskVidFlag
    fprintf('Orthogonalising VIDEO w.r.t TASK...\n');
    P_task = taskBlock * pinv(taskBlock' * taskBlock) * taskBlock';
    vidBlock = vidBlock - P_task * vidBlock;
end

% Trial w.r.t Task + Video
if crossCorrTaskTrialFlag || crossCorrVidTrialFlag
    fprintf('Orthogonalising TRIAL w.r.t TASK + VIDEO...\n');
    regBlock = [taskBlock, vidBlock];
    P_reg = regBlock * pinv(regBlock' * regBlock) * regBlock';
    trialBlock = trialBlock - P_reg * trialBlock;
end

%% Step 5: Update final orthogonalised matrix robustly
if ~isempty(taskBlock) && ~isempty(taskIdx) && isnumeric(taskIdx)
    nCols = length(taskIdx);
    if size(taskBlock,2) == nCols
        fullR_ortho(:, taskIdx) = taskBlock;
    else
        warning('TASK block has %d columns but taskIdx has %d entries. Skipping assignment.', size(taskBlock,2), nCols);
    end
end

if ~isempty(vidBlock) && ~isempty(vidIdx) && isnumeric(vidIdx)
    nCols = length(vidIdx);
    if size(vidBlock,2) == nCols
        fullR_ortho(:, vidIdx) = vidBlock;
    else
        warning('VIDEO block has %d columns but vidIdx has %d entries. Skipping assignment.', size(vidBlock,2), nCols);
    end
end

if ~isempty(trialBlock) && ~isempty(trialIdx) && isnumeric(trialIdx)
    nCols = length(trialIdx);
    if size(trialBlock,2) == nCols
        fullR_ortho(:, trialIdx) = trialBlock;
    else
        warning('TRIAL block has %d columns but trialIdx has %d entries. Skipping assignment.', size(trialBlock,2), nCols);
    end
end

end
