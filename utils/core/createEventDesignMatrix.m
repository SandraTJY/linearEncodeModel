function [taskLabels, taskMat, taskIdx] = createEventDesignMatrix(obj, fullR, options)
    % *createEventDesignMatrix*: constructs time-lagged regressors for
    % stim-, reward-, and choice-related signals separately in the entire timeline.
    %
    % INPUT:
    % - obj: class object (can be empty if used outside class context)
    % - fullR: table of raw behavioral regressors (not time-lagged)
    % - options: configuration struct defined at the beginning of the analysis
    %
    % OUTPUT:
    % - taskLabels: cell array of task (event) regressor names (expanded)
    % - taskMat: combined padded time-lagged design matrix [frames x total_lags]
    % - taskIdx: vector indexing which original regressor (by position) each column belongs to

    % --- Define frame windows ---
    fields = fieldnames(options.variableDefs);
    taskLabels = {};
    preFramesPerVar = [];
    postFramesPerVar = [];

    fprintf('\n==== [DEBUG] Group order in options.variableDefs ====\n');
    disp(fields');  % show defined variable groups (order of processing)
    fprintf('=====================================================\n\n');

    % --- Expand wildcards and collect beta times ---
    for f = 1:numel(fields)
        key = fields{f};
        def = options.variableDefs.(key);

        if isfield(def, 'type') && strcmp(def.type, 'event')
            vars = def.vars;
            if isempty(vars)
                continue;
            end

            fprintf('--- Group: %s ---\n', key);
            for iVars = 1:numel(vars)
                pattern = vars{iVars};
                matchIdx = find(~cellfun(@isempty, regexp(fullR.Properties.VariableNames, pattern, 'once')));

                if isempty(matchIdx)
                    warning('No matches found for pattern "%s" in fullR table.', pattern);
                    continue;
                end

                % Sort matches alphabetically for consistency
                matches = sort(fullR.Properties.VariableNames(matchIdx));

                fprintf('Pattern "%s" matched: %s\n', pattern, strjoin(matches, ', '));

                % Add expanded labels
                taskLabels = [taskLabels, matches];

                % Get beta times
                if isfield(def, 'betaPreTime'), preTime = def.betaPreTime; else, preTime = 0; end
                if isfield(def, 'betaPostTime'), postTime = def.betaPostTime; else, postTime = 0; end

                if preTime == 0
                    warning('Event variable "%s" has betaPreTime = 0 (no pre-event extension).', pattern);
                end
                if postTime == 0
                    warning('Event variable "%s" has betaPostTime = 0 (no post-event extension).', pattern);
                end

                preFramesPerVar  = [preFramesPerVar, repmat(round(preTime*obj.sRate), 1, numel(matches))];
                postFramesPerVar = [postFramesPerVar, repmat(round(postTime*obj.sRate), 1, numel(matches))];
            end
            fprintf('\n');
        end
    end

    % --- Final sanity check before building lagged regressors ---
    if length(taskLabels) ~= length(preFramesPerVar)
        error('Mismatch between number of task labels (%d) and preFrame entries (%d).', ...
              length(taskLabels), length(preFramesPerVar));
    end

    fprintf('==== [DEBUG] Final expanded task label order ====\n');
    for i = 1:numel(taskLabels)
        fprintf('%2d: %s (pre=%d, post=%d)\n', i, taskLabels{i}, preFramesPerVar(i), postFramesPerVar(i));
    end
    fprintf('================================================\n\n');

    % --- Build lagged regressors ---
    nFrames = size(fullR,1);
    taskMat = []; %sparse(nFrames, 0);
    taskIdx = [];

    for iLabel = 1:length(taskLabels)
        label = taskLabels{iLabel};
        preFrames  = preFramesPerVar(iLabel);
        postFrames = postFramesPerVar(iLabel);

        [lagMat, ~] = expandSingleRegressor(fullR{:, label}, preFrames, postFrames);

        % Ensure sparse
        if ~issparse(lagMat)
            lagMat = sparse(lagMat);
        end

        % Append
        taskMat = [taskMat, lagMat]; %#ok<AGROW>
        taskIdx = [taskIdx; repmat(iLabel, size(lagMat, 2), 1)]; %#ok<AGROW>
    end

    % --- Print summary of taskIdx mapping ---
    fprintf('\n==== [DEBUG] taskIdx mapping summary ====\n');
    uniqueLabels = unique(taskIdx);
    for i = 1:numel(uniqueLabels)
        idx = uniqueLabels(i);
        fprintf('Label %2d (%s): %d lag columns\n', idx, taskLabels{idx}, sum(taskIdx == idx));
    end
    fprintf('==========================================\n\n');
end
