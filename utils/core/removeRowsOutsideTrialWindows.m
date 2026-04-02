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
    nTimePoints = numel(obj.globalTime);

    trialVecFull = zeros(nTimePoints, 1);
    trialCounter = 1;

    % --- 1. Determine pre/post windows based on first and last events ---
    fields = fieldnames(obj.variableDefs);
    firstPre = 0;
    lastPost = 0;
    firstEventFound = false;
    lastEventFound  = false;

    for f = 1:numel(fields)
        def = obj.variableDefs.(fields{f});
        if strcmp(def.type, 'event')
            % Check if this event matches the first or last trial event
            if isfield(def, 'timeRef')
                if strcmp(def.timeRef, obj.firstTrialEvent)
                    firstPre = def.betaPreTime;
                    firstEventFound = true;
                end
                if strcmp(def.timeRef, obj.lastTrialEvent)
                    lastPost = def.betaPostTime;
                    lastEventFound = true;
                end
            end
        end
    end

    if ~firstEventFound
        warning('⚠️ First trial event "%s" not found in variableDefs. Using 0.', obj.firstTrialEvent);
    end
    if ~lastEventFound
        warning('⚠️ Last trial event "%s" not found in variableDefs. Using 0.', obj.lastTrialEvent);
    end

    prevTEnd = -inf; % Track previous trial end

    % --- 2. Build trial vector with clipping ---
    for t = 1:nTrials
        tStartVal = obj.bhv.(obj.firstTrialEvent)(t);
        tEndVal   = obj.bhv.(obj.lastTrialEvent)(t);

        if isempty(tStartVal) || isempty(tEndVal) || any(isnan([tStartVal, tEndVal]))
            continue;
        end

        rawTStart = tStartVal - firstPre;
        rawTEnd   = tEndVal   + lastPost;

        % Clip overlaps: ensure this trial doesn’t start before previous ends
        if rawTStart < prevTEnd
            overlapAmount = prevTEnd - rawTStart;
            fprintf('⚠️ Trial %d starts %.3f s before previous trial ended. Clipping start forward by %.3f s.\n', ...
                    t, overlapAmount, overlapAmount);
            rawTStart = prevTEnd + (obj.globalTime(2) - obj.globalTime(1)); % move forward by 1 sample
        end
        prevTEnd = rawTEnd;

        % Map times to indices
        startIdx = findClosestTimeIdx(obj.globalTime, rawTStart);
        endIdx   = findClosestTimeIdx(obj.globalTime, rawTEnd);

        % Guard boundaries
        startIdx = max(1, startIdx);
        endIdx   = min(nTimePoints, endIdx);

        if startIdx > endIdx
            fprintf('⚠️ Trial %d has invalid window (startIdx > endIdx). Skipping.\n', t);
            continue;
        end

        trialVecFull(startIdx:endIdx) = trialCounter;
        trialCounter = trialCounter + 1;
    end

    % --- 3. Remove rows outside trial windows ---
    zeroRows = (trialVecFull == 0);

    % Sanity checks
    if size(refMat, 1) ~= nTimePoints
        error('refMat row count (%d) ≠ globalTime length (%d).', size(refMat, 1), nTimePoints);
    end

    cleanedRefMat = refMat(~zeroRows, :);

    % Clean other matrices
    cleanedMats = cell(1, numel(varargin) + 1);
    cleanedMats{1} = cleanedRefMat;

    for i = 1:numel(varargin)
        mat = varargin{i};
        if isempty(mat)
            cleanedMats{i+1} = [];
            continue;
        end
        if size(mat, 1) ~= nTimePoints
            error('Matrix %d row count (%d) ≠ globalTime length (%d).', ...
                  i, size(mat, 1), nTimePoints);
        end
        cleanedMats{i+1} = mat(~zeroRows, :);
    end

    trialVec = trialVecFull(~zeroRows);

    fprintf('\n Finished building trial windows. %d valid trials retained.\n', ...
            numel(unique(trialVec)));

end

