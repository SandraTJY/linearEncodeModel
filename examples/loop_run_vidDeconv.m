%% loop_run_vidDeconv 
% Configuration file for running the linear encoding model. Ensure that the 
% options struct, event, neural and video (optional) data is loaded before 
% running the configuration file.

% Define subjects and sessions
mouseList = options.animal;
sessionListFull = unique(obj.bhv.expRef);
sessionList = {erase(sessionListFull, ['_' mouseName])}; % removing the underscore and animal name in expRef

for i = 1:length(mouseList)
    mouse = mouseList{i};
    session = sessionList{i};
    expRef = strcat(session, '_', mouse);

    try
        % 1. Setup session model struct
        obj = setupLinearEncodeModel(obj, mouse, session, options);

        % 2. Build event regressors
        obj = buildEventRegressors(obj, options);

        % 3. Build video regressor
        obj = buildContinuousRegressors(obj, options);

        % 4. Build whole trial regressor
        obj = buildTrialRegressors(obj, options);

        % 5. Get non-expanded design matrix for event regressors
        R = getEventDesignMatrix(obj, options); % event regressors should be separated from the video and the trial regressors for expansion.

        % 6. Create task and video regressors
        [taskLabels, taskMat, taskIdx] = createTaskDesignMatrix(obj, R, options);
        [vidLabels, vidMat, vidIdx] = createVideoDesignMatrix(obj, options);
        [trialLabels, trialMat, trialIdx] = createTrialDesignMatrix(obj, options);

        % 7. Visualise design matrix separately
        % Note: although plotDesignMatrix works with concatenated expanded
        % ones, since expandR is not normalised, it is difficult to
        % visualise the event kernels there - video PCs has larger values than events
        % (normalisation happens in ridgeMML). 
        plotDesignMatrix(taskMat, options);
        plotDesignMatrix(vidMat, options);
        plotDesignMatrix(trialMat, options);

        % 8. Remove zero-rows (i.e., not related to the task events), and
        % some data wrangling
        [cleanedMats, zeroOnlyRows, trialVec] = removeRowsOutsideTrialWindows(obj, taskMat, taskMat, vidMat, trialMat, obj.LeftDLS_DA', obj.RightDLS_ACH');

        taskMatClean = cleanedMats{1};
        vidMatClean  = cleanedMats{2};
        trialMatClean  = cleanedMats{3};
        obj.fluorDALeftClean   = cleanedMats{4}';
        obj.fluorACHRightClean = cleanedMats{5}';

        % 9. Normalise and recentre the expanded, clean matrix to avoid
        % computational issues down the line, and add small jitter
        expandR_raw = [taskMatClean, vidMatClean, trialMatClean]; % Get the predictor regressor matrix
        regLabels = [taskLabels, vidLabels, trialLabels]; % % Get the labels for predictor regressor matrix
        [expandR_standardised, obj.fluorDALeftCleanStandardised] = normaliseAndRecentre(expandR_raw, obj.fluorDALeftClean); 
        [expandR_standardised, obj.fluorACHRightCleanStandardised] = normaliseAndRecentre(expandR_raw, obj.fluorACHRightClean); 

        % 10: Check for high correlation and linear dependence, if R <
        % 0.95 and/or any columns have linear dependency, orthogonalise the
        % columns accordingly
        corrThresh = 0.95;
        [expandR, regIdx] = checkAndOrthogonalise(expandR_standardised, taskLabels, vidLabels, trialLabels, taskIdx, vidIdx, trialIdx, corrThresh);

        % 10. Ridge regression
        [ridgeDALambda, ridgeDABeta]   = ridgeMML(expandR_standardised, obj.fluorDALeftCleanStandardised', [], true, 30); % Initial search values of lamba should be positive
        [ridgeACHLambda, ridgeACHBeta] = ridgeMML(expandR_standardised, obj.fluorACHRightCleanStandardised', [], true, 30); % Initial search values of lamba should be positive

        % 11. Run cross-validated encoding model
        [fluorDAPred, fullBeta_DA, ~, fullIdx, fullRidge, fullLabels] = ...
                crossValModel(expandR_standardised, obj.fluorDALeftCleanStandardised, regLabels, regIdx, regLabels, 10, trialVec);
        [fluorACHPred, fullBeta_ACH, ~, fullIdx, fullRidge, fullLabels] = ...
                crossValModel(expandR_standardised, obj.fluorACHRightCleanStandardised, regLabels, regIdx, regLabels, 10, trialVec);

    catch ME
        warning("Processing failed for %s - %s: %s", mouse, session, ME.message);
    end
end

