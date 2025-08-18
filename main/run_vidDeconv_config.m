function obj = run_vidDeconv_config(obj, mouse, session, options)
% RUN_VIDDECONV_CONFIG 
% Runs the linear encoding model for a single animal/session.
% This script checks which variableDefs are defined in options and 
% executes only the relevant steps.

expRef = strcat(session, '_', mouse);

% ---- Check mandatory fields ----
varNames = fieldnames(options.variableDefs);

hasEvent  = any(cellfun(@(f) strcmpi(options.variableDefs.(f).type, 'event'), varNames));
hasNeural = any(cellfun(@(f) strcmpi(options.variableDefs.(f).type, 'neural'), varNames));

if ~hasEvent
    error('No EVENT regressors defined in options.variableDefs (mandatory).');
end
if ~hasNeural
    error('No NEURAL regressors defined in options.variableDefs (mandatory).');
end


try
    %% 1. Setup session model struct
    obj = setupLinearEncodeModel(obj, mouse, session, options);

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
    [taskLabels, taskMat, taskIdx] = createTaskDesignMatrix(obj, R, options);

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
    neuralRefs   = options.variableDefs.neural.timeRef;
    neuralInputs = cellfun(@(x) obj.(x)', neuralRefs, 'UniformOutput', false);
    
    % Ensure vidMat/trialMat exist
    if ~exist('vidMat', 'var');   vidMat   = []; end
    if ~exist('trialMat', 'var'); trialMat = []; end
    
    [cleanedMats, zeroOnlyRows, trialVec] = removeRowsOutsideTrialWindows( ...
        obj, taskMat, taskMat, vidMat, trialMat, neuralInputs{:});
    
    taskMatClean  = cleanedMats{1};
    vidMatClean   = cleanedMats{2};
    trialMatClean = cleanedMats{3};
    
    % assign cleaned neural signals dynamically
    for n = 1:numel(neuralRefs)
        obj.([neuralRefs{n} 'Clean']) = cleanedMats{3+n}';
    end

    %% 8. Normalise and recentre
    expandR_raw = [taskMatClean, vidMatClean, trialMatClean];
    regLabels   = [taskLabels, vidLabels, trialLabels];

    for n = 1:numel(neuralRefs)
        [expandR_standardised, obj.([neuralRefs{n} 'CleanStandardised'])] = ...
            normaliseAndRecentre(expandR_raw, obj.([neuralRefs{n} 'Clean']));
    end

    %% 9. Check for correlation/orthogonalise
    corrThresh = 0.95;
    [expandR, regIdx] = checkAndOrthogonalise( ...
        expandR_standardised, taskLabels, vidLabels, trialLabels, ...
        taskIdx, vidIdx, trialIdx, corrThresh);

    %% 10. Ridge regression + cross validation for each neural regressor
    for n = 1:numel(neuralRefs)
        y = obj.([neuralRefs{n} 'CleanStandardised'])';

        [ridgeLambda, ridgeBeta] = ridgeMML(expandR_standardised, y, [], true, 30);
        obj.([neuralRefs{n} '_ridgeLambda']) = ridgeLambda;
        obj.([neuralRefs{n} '_ridgeBeta'])   = ridgeBeta;

        [pred, fullBeta, ~, fullIdx, fullRidge, fullLabels] = ...
            crossValModel(expandR_standardised, y, regLabels, regIdx, regLabels, 10, trialVec);

        obj.([neuralRefs{n} '_Pred'])   = pred;
        obj.([neuralRefs{n} '_fullBeta']) = fullBeta;
    end

catch ME
    warning("Processing failed for %s - %s: %s", mouse, session, ME.message);
end
end
