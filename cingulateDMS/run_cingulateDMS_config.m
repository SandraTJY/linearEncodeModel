function obj = run_cingulateDMS_config(obj, session, options)
    % *RUN_VIDDECONV_CONFIG* 
    % Runs the linear encoding model for a single animal/session.
    % This script checks which variableDefs are defined in options and 
    % executes only the relevant steps.

    try
        % ---- Check mandatory fields ----
        varNames = fieldnames(options.variableDefs);

        validTypes = {'event', 'continuous', 'neural', 'trial'};

        % Initialise flags
        hasEvent  = false;
        hasNeural = false;

        for i = 1:numel(varNames)
            def = options.variableDefs.(varNames{i});

            % (1) Type must be defined and valid
            if ~isfield(def, 'type') || isempty(def.type)
                error('Field "%s" is missing a valid "type".', varNames{i});
            elseif ~ismember(lower(def.type), validTypes)
                error('Field "%s" has invalid type "%s". Must be one of: %s', ...
                    varNames{i}, def.type, strjoin(validTypes, ', '));
            end

            % (2) Each field must have at least one variable in "vars"
            if ~isfield(def, 'vars') || isempty(def.vars)
                error('Field "%s" has no variables defined in "vars".', varNames{i});
            end

            % (3) Only one timeRef per field
            if ~isfield(def, 'timeRef') || isempty(def.timeRef)
                error('Field "%s" is missing "timeRef".', varNames{i});
            elseif iscell(def.timeRef) && numel(def.timeRef) > 1
                error('Field "%s" has multiple entries in "timeRef" (must be exactly one).', varNames{i});
            end

            % (4) Only event type can have beta kernel definitions
            if strcmpi(def.type, 'event')
                % betaPreTime and betaPostTime are optional, but allowed
                % (you could also assert they must exist if that's stricter)
            else
                if isfield(def, 'betaPreTime') || isfield(def, 'betaPostTime')
                    error('Field "%s" of type "%s" must not define beta kernels.', varNames{i}, def.type);
                end
            end

            % Update flags
            if strcmpi(def.type, 'event')
                hasEvent = true;
            elseif strcmpi(def.type, 'neural')
                hasNeural = true;
            end
        end

        % (5) There must be at least one neural and one event field
        if ~hasEvent
            error('No EVENT regressors defined in options.variableDefs (mandatory).');
        end
        if ~hasNeural
            error('No NEURAL regressors defined in options.variableDefs (mandatory).');
        end

        %% 1. Setup session model struct
        obj = setupLinearEncodeModel(obj, session, options);

        %% 2. Build event regressors
        obj = buildEventRegressors(obj, options);

        %% 3. Build optional regressors
        varNames = fieldnames(options.variableDefs);

        % ---- Continuous regressors (e.g., video, keypoints) ----
        hasContinuous = any(cellfun(@(f) strcmpi(options.variableDefs.(f).type, 'continuous'), varNames));

        if hasContinuous
            obj = buildContinuousRegressors(obj, options);
            [vidLabels, vidMat, vidIdx] = createVideoDesignMatrix(obj, options);
        else
            fprintf('No continuous regressors are defined...\n');
            vidLabels = {}; vidMat = []; vidIdx = [];
        end

        % ---- Trial regressors (averages, choice history, etc.) ----
        hasTrial = any(cellfun(@(f) strcmpi(options.variableDefs.(f).type, 'trial'), varNames));

        if hasTrial
            obj = buildTrialRegressors(obj, options);
            [trialLabels, trialMat, trialIdx] = createTrialDesignMatrix(obj, options);
        else
            fprintf('No trial regressors are defined...\n');
            trialLabels = {}; trialMat = []; trialIdx = [];
        end

        %% 4. Get non-expanded design matrix for event regressors
        R = getEventDesignMatrix(obj, options);

        %% 5. Create task/video/trial regressors
        [taskLabels, taskMat, taskIdx] = createEventDesignMatrix(obj, R, options);

        if exist('vidMat','var')
            [vidLabels, vidMat, vidIdx] = createVideoDesignMatrix(obj, options);
        else
            vidLabels = {}; vidMat = []; vidIdx = [];
        end

        if exist('trialMat','var')
            [trialLabels, trialMat, trialIdx] = createTrialDesignMatrix(obj, options);
        else
            trialLabels = {}; trialMat = []; trialIdx = [];
        end

        %% 6. Visualise (optional)
        if isfield(options, 'plotDesignMatrix') && options.plotDesignMatrix
            plotDesignMatrix(taskMat, options);
            if ~isempty(vidMat),   plotDesignMatrix(vidMat, options);   end
            if ~isempty(trialMat), plotDesignMatrix(trialMat, options); end
        end

        %% 7. Remove zero-rows (include dynamic neural regressors)
        % neuralRefs   = options.variableDefs.neural.vars;
        % neuralInputs = cellfun(@(x) obj.(x)', neuralRefs, 'UniformOutput', false);
        %
        % % Ensure vidMat/trialMat exist
        % if ~exist('vidMat', 'var');   vidMat   = []; end
        % if ~exist('trialMat', 'var'); trialMat = []; end
        %
        % % --- Determine row counts ---
        % allMatrices = [{taskMat}, {vidMat}, {trialMat}, neuralInputs];
        % rowCounts = cellfun(@(x) size(x,1), allMatrices);
        %
        % neuralInputs = cellfun(@(x) x, neuralInputs, 'UniformOutput', false);
        %
        % [cleanedMats, zeroOnlyRows, trialVec] = removeRowsOutsideTrialWindows( ...
        %     obj, taskMat, taskMat, vidMat, trialMat, neuralInputs{:});
        %
        % % First three are task/vid/trial
        % taskMatClean   = cleanedMats{1};
        % vidMatClean    = cleanedMats{2}; % Will remain empty if not defined
        % trialMatClean  = cleanedMats{3}; % Will remain empty if not defined
        %
        % % Then loop through neural refs
        % for n = 1:numel(neuralRefs)
        %     obj.([neuralRefs{n} 'Clean']) = cleanedMats{3+n};  % +3 offset
        % end

        % --- Expand neural references and collect inputs ---
        expandedNeuralRefs = expandFieldPatterns(obj, options.variableDefs.neural.vars);
        neuralInputs = cellfun(@(x) obj.(x)', expandedNeuralRefs, 'UniformOutput', false);

        % Ensure vidMat/trialMat exist
        if ~exist('vidMat','var') || isempty(vidMat);   vidMat   = zeros(size(taskMat,1),0); end
        if ~exist('trialMat','var') || isempty(trialMat); trialMat = zeros(size(taskMat,1),0); end

        % --- Remove zero-rows ---
        [cleanedMats, zeroOnlyRows, trialVec] = removeRowsOutsideTrialWindows( ...
            obj, taskMat, taskMat, vidMat, trialMat, neuralInputs{:});

        % --- Assign cleaned matrices ---
        [taskMatClean, vidMatClean, trialMatClean] = deal(cleanedMats{1:3});

        obj.taskMatClean = taskMatClean;

        if ~isempty(vidMatClean)
            obj.vidMatClean = vidMatClean;
        end

        if ~isempty(trialMatClean)
            obj.trialMatClean = trialMatClean;
        end

        for n = 1:numel(expandedNeuralRefs)
            obj.([expandedNeuralRefs{n} 'Clean']) = cleanedMats{3+n};
        end

        %% 8. Normalise and recentre
        expandR_raw = [taskMatClean, vidMatClean, trialMatClean];
        regLabels   = [taskLabels, vidLabels, trialLabels];

        for n = 1:numel(expandedNeuralRefs)
            [expandR_standardised, obj.([expandedNeuralRefs{n} 'CleanStandardised'])] = ...
                normaliseAndRecentre(expandR_raw, obj.([expandedNeuralRefs{n} 'Clean']));
        end

        %% 9. Check for correlation/orthogonalise
        corrThresh = 0.95;
        [expandR_checked, regIdx] = checkAndOrthogonalise( ...
            expandR_standardised, taskLabels, vidLabels, trialLabels, ...
            taskIdx, vidIdx, trialIdx, corrThresh);

        % Store regLabels and regIdx in obj.crossVal.model_details
        obj.crossVal.model_details = struct();
        obj.crossVal.model_details.full = struct('regLabels', regLabels,...
                                                'regIdx', regIdx);

        %% 10. Ridge regression + cross validation for each neural regressor
        for n = 1:2 %numel(expandedNeuralRefs)
            y = obj.([expandedNeuralRefs{n} 'CleanStandardised']);

            % Run ridge MML regression
            [ridgeLambda, ridgeBeta] = ridgeMML(expandR_checked, y, [0.01, 0.1, 1, 10], true, 30);
            obj.([expandedNeuralRefs{n} '_ridgeLambda']) = ridgeLambda;
            obj.([expandedNeuralRefs{n} '_ridgeBeta'])   = ridgeBeta;

            % Run full model 10-fold cross validation
            numFolds = 5;
            [fullPred, fullBeta, ~, fullIdx, fullRidge, fullLabels] = ...
                crossValModel(expandR_checked, y, regLabels, regIdx, regLabels, numFolds, trialVec);

            r_fullModel = corr(fullPred(:), y(:)); % Calculate full model Pearson's R
            R2_fullModel = r_fullModel^2; % Calculate R2 (goodness of fit)

            % Save full model data
            obj.crossVal.(expandedNeuralRefs{n}).full = struct( ...
                'Pred', fullPred, ...
                'Beta', fullBeta, ...
                'r', r_fullModel, ...
                'R2', R2_fullModel ...
                );

            % Run subset model 10-fold cross validation
            eventGroups = fieldnames(obj.variableDefs);
            for iG = 1:numel(eventGroups)
                groupName = eventGroups{iG};
                groupDef  = obj.variableDefs.(groupName);

                % Skip neural group
                if strcmp(groupDef.type, 'neural')
                    continue
                end

                % Collect all subset matches for this group
                subsetMatchIdx = [];
                for iVars = 1:numel(groupDef.vars)
                    thisVar = groupDef.vars{iVars};

                    % Expand wildcard using regex against obj.bhv columns
                    theseMatches = find(~cellfun(@isempty, regexp(taskLabels, thisVar, 'once')));
                    subsetMatchIdx = [subsetMatchIdx theseMatches];
                end
                subsetMatchIdx = unique(subsetMatchIdx); % avoid duplicates

                if isempty(subsetMatchIdx)
                    warning('Group "%s" did not match any regressors in taskMat. Skipping.', groupName);
                    continue
                end

                % Run model on this group
                [subsetPred, subsetBeta, ~, ~, ~, ~] = crossValModel( ...
                    taskMat, y, taskLabels(subsetMatchIdx), taskIdx, taskLabels, numFolds, trialVec);

                r_subsetModel     = corr(subsetPred(:), y(:));
                R2_subsetModel    = r_subsetModel^2;
                DeltaR2_subsetModel = (R2_subsetModel - R2_fullModel) / R2_fullModel;

                % Calculate relative change in R2
                if abs(R2_fullModel) < 1e-6
                    warning('R² of full model is near zero (%.5f). DeltaR² calculation may be unreliable or produce Inf/NaN.', R2_fullModel);
                    DeltaR2_subsetModel = NaN;  % assign NaN to avoid misleading values
                else
                    DeltaR2_subsetModel = (R2_subsetModel - R2_fullModel) / R2_fullModel;
                end

                % With all subset results
                subsetResults = struct( ...
                    'Pred',    subsetPred, ...
                    'Beta',    subsetBeta, ...
                    'r',       r_subsetModel, ...
                    'R2',      R2_subsetModel, ...
                    'DeltaR2', DeltaR2_subsetModel);

                % Save under the group name
                obj.crossVal.(expandedNeuralRefs{n}).subset.(sprintf('exclu_%s', groupName)) = subsetResults;
            end
        end

    catch ME
        fprintf('---\nProcessing failed for session: %s\n', session);
        fprintf('Error message: %s\n', ME.message);
        fprintf('Stack trace (most recent call first):\n');
        for k = 1:length(ME.stack)
            fprintf('  File: %s\n  Function: %s\n  Line: %d\n', ...
                ME.stack(k).file, ME.stack(k).name, ME.stack(k).line);
        end
    end
end
