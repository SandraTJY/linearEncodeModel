function [cleanedMats, zeroRows, trialVec] = removeRowsOutsideTrialWindows(obj, refMat, varargin)
    % removeRowsOutsideTrialWindows Removes rows outside trial time windows.
    %
    % INPUTS:
    %   - *obj*: object containing behavioral data with stimulusOnsetTime and outcomeTime
    %   - *refMat*: reference matrix (same rows as timeVec), used to filter rows
    %   - *varargin*: other matrices to be filtered (must have same row count)
    %
    % OUTPUTS:
    %   - *cleanedMats*: cell array of filtered matrices (no rows outside trial windows)
    %   - *zeroRows*: logical vector indicating rows removed (true = removed)
    %   - *trialVec*: vector labeling each row with trial number (0 = outside any trial)

nTrials = height(obj.bhv);
nTimePoints = length(obj.globalTime);

% Initialise trial vector with zeros (0 means outside trial window)
trialVec = zeros(nTimePoints, 1);
trialCounter = 1;

% Use global trial boundaries (not per event field)
for t = 1:nTrials
    % Default pre/post time windows
    preTime = 0;
    postTime = 0;

    fields = fieldnames(obj.variableDefs);
    for f = 1:numel(fields)
        def = obj.variableDefs.(fields{f});
        if strcmp(def.type, 'event')

            % Pre time check
            if ~isfield(def, 'betaPreTime') || def.betaPreTime == 0
                error('Event "%s" has betaPreTime = 0 (must be > 0).', fields{f});
            else
                preTime = max(preTime, def.betaPreTime);
            end

            % Post time check
            if ~isfield(def, 'betaPostTime') || def.betaPostTime == 0
                error('Event "%s" has betaPostTime = 0 (must be > 0).', fields{f});
            else
                postTime = max(postTime, def.betaPostTime);
            end
        end
    end

    % Compute trial boundaries
    rawTStart = obj.bhv.(obj.firstTrialEvent)(t) - preTime;
    rawTEnd   = obj.bhv.(obj.lastTrialEvent)(t) + postTime;

    % Find closest indices in global time vector
    startIdx = findClosestTimeIdx(obj.globalTime, rawTStart);
    endIdx   = findClosestTimeIdx(obj.globalTime, rawTEnd);

    % Mark the trial rows within the window
    trialVec(startIdx:endIdx) = trialCounter;
    trialCounter = trialCounter + 1;
end

% Rows outside any trial have trialVec == 0
zeroRows = (trialVec == 0);

% Remove zero rows from refMat
cleanedRefMat = refMat(~zeroRows, :);

% Remove zero rows from all varargin matrices and store in cleanedMats
cleanedMats = cell(size(varargin));
for i = 1:numel(varargin)
    mat = varargin{i};

    if isempty(mat)
        cleanedMats{i} = [];
        continue;
    end

    if size(mat, 1) ~= nTimePoints
        error('Matrix %d row count does not match timeVec length.', i);
    end

    cleanedMats{i} = mat(~zeroRows, :);
end

% Also update trialVec to only include remaining rows
trialVec = trialVec(~zeroRows);

end

