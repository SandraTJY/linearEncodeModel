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

% NOTE1: linear dependency is likely to happen when regression combines both binary and continuous variables together. 
% If linear dependency is detected, this function adds a small jitter to
% the design matrix and rerun the QR decomposition test. If it returns as
% linear dependent again, it is likely due to a strutural issue in linear
% dependency, rather than numerical instability

% NOTE2: pairwise correlation and QR decomposition is computational
% expensive, upon loading and computing for large data sheets it might
% crash. I revise this function in a way that 1) correlation and QR
% decomposition is done in groups/ subsampled rows (if row > 5000) to reduce 
% computational load, and limit cores (MacOS is often overparallelised) - this 
% might be slightly slower but it is more numerically stable and memory-safe.

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
vidCols    = [];
trialCols  = [];

nTaskCols = numel(taskIdx);   % expanded number of task columns
nVidCols  = numel(vidIdx);    % number of video columns
nTrialCols = numel(trialIdx); % number of trial columns

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

%% --- Debug print for verification ---
fprintf('\n[DEBUG] checkAndOrthogonalise input summary:\n');
fprintf('   Task regressors:  %d (%s)\n', nTaskCols, strjoin(taskLabels, ', '));
fprintf('   Video regressors: %d (%s)\n', nVidCols,  strjoin(vidLabels, ', '));
fprintf('   Trial regressors: %d (%s)\n', nTrialCols, strjoin(trialLabels, ', '));
fprintf('------------------------------------------------------\n');

%% Step 1: Within-group orthogonalisation
groups = {'TASK', 'VIDEO', 'TRIAL'};
blocks = {taskBlock, vidBlock, trialBlock};
idxBlocks = {taskIdx, vidCols, trialCols};

for g = 1:length(groups)
    block = blocks{g};
    idx   = idxBlocks{g};

    if isempty(block) || size(block,2) <= 1
        fprintf('%s group empty or single regressor — skipping QR.\n', groups{g});
        continue;
    end

    % Pairwise correlation check
    Rblock = corr(full(block));
    highCorr = any(any(abs(Rblock - diag(diag(Rblock))) > corrThresh));

    % Rank check
    [~, R] = qr(full(block), 0);
    tol = max(size(block)) * eps(norm(R, 'fro'));
    r = sum(abs(diag(R)) > tol);

    % Orthogonalise if rank-deficient or highly correlated
    if r < size(block, 2)
        fprintf('%s regressors rank-deficient (%d < %d). Orthogonalising...\n', ...
            groups{g}, r, size(block,2));
        [Q, ~] = qr(full(block), 0);
        block = Q;
    elseif highCorr
        fprintf('High correlation detected in %s regressors. Orthogonalising...\n', groups{g});
        [Q, ~] = qr(full(block), 0);
        block = Q;
    else
        fprintf('%s regressors OK.\n', groups{g});
    end

    % Update orthogonalised block
    if ~isempty(idx)
        fullR_ortho(:, idx) = block;
    end

    blocks{g} = block;
end

[taskBlock, vidBlock, trialBlock] = deal(blocks{:});

%% Step 2: Cross-group correlation flags
crossCorrTaskVidFlag   = ~isempty(taskBlock) && ~isempty(vidBlock) && ...
    any(any(abs(corr(taskBlock, vidBlock)) > corrThresh));
crossCorrTaskTrialFlag = ~isempty(taskBlock) && ~isempty(trialBlock) && ...
    any(any(abs(corr(taskBlock, trialBlock)) > corrThresh));
crossCorrVidTrialFlag  = ~isempty(vidBlock) && ~isempty(trialBlock) && ...
    any(any(abs(corr(vidBlock, trialBlock)) > corrThresh));

%% Step 3: Overall rank deficiency check with jitter
smallR = [taskBlock, vidBlock, trialBlock];
if ~isempty(smallR)
    [~, R, E] = qr(smallR, 0);
    tol = max(size(smallR)) * eps(norm(R, 'fro'));
    r_before = sum(abs(diag(R)) > tol);

    if r_before < size(smallR,2)
        warning('Overall rank deficiency detected: %d cols.\n', size(smallR,2) - r_before);
        epsilon = eps(norm(smallR, 'fro'));
        smallR_jitter = smallR + epsilon * randn(size(smallR));
        [~, R, E] = qr(smallR_jitter, 0);
        tol = max(size(smallR_jitter)) * eps(norm(R, 'fro'));
        r_after = sum(abs(diag(R)) > tol);

        fprintf('Rank before: %d, after jitter: %d\n', r_before, r_after);
        if r_after < size(smallR,2)
            warning('Structural rank deficiency remains.\n');
            depCols = sort(E(r_after+1:end));
            disp('Dependent regressors:');
            disp(regLabels(regIdx(depCols))');
        end
    else
        fprintf('No overall rank deficiency.\n');
    end
else
    fprintf('No regressors for rank check.\n');
end

%% Step 4: Cross-group orthogonalisation if needed
if crossCorrTaskVidFlag
    fprintf('Orthogonalising VIDEO w.r.t TASK...\n');
    Q_task = orth(taskBlock);
    vidBlock = vidBlock - Q_task * (Q_task' * vidBlock);
    fullR_ortho(:, vidIdx) = vidBlock;
end

if crossCorrTaskTrialFlag || crossCorrVidTrialFlag
    fprintf('Orthogonalising TRIAL w.r.t TASK + VIDEO...\n');
    regBlock = [taskBlock, vidBlock];
    Q_reg = orth(regBlock);
    trialBlock = trialBlock - Q_reg * (Q_reg' * trialBlock);
    fullR_ortho(:, trialIdx) = trialBlock;
end

end