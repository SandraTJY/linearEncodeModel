function obj = buildTrialRegressors(obj, options)
    % *buildTrialRegressors*: a function that creates trial-based regressors
    % and compiles them into a *non-time shifted, non-expanded* design matrix.
    % This function processes variables defined in *options.variableDefs* that 
    % have their *type* set to 'trial'. For each trial-defined variable, it 
    % fills the regressor values across the entire trial duration in 
    % *obj.globalTime*. For continuous data, trial-mean values are computed 
    % and replicated across the trial window.
    %
    % INPUT:
    % - *obj* (can be kept empty): the object instance from the linearEncodeModel 
    %   class that was created previously. In MATLAB, this is just a syntax to 
    %   call the function as it belongs to the method of the class 
    %   *linearEncodeModel()*.
    %
    % - *options*: the configuration struct that is defined at the beginning 
    %   of the analysis, containing *variableDefs* with fields specifying:
    %     - type: must be 'trial' for this function to process
    %     - timeRef: the time reference(s) for the trial (start/end times)
    %     - vars: a list of variable names to extract from *obj.bhv* or *obj.vid*
    %
    % OUTPUT:
    % - *obj*: the updated object instance from the linearEncodeModel class 
    %   with new subfields containing the trial-based regressors in the 
    %   non-time shifted design matrix. These regressors have constant values 
    %   across each trial's time range in *obj.globalTime*.

    % Get all variable definitions
    varDefs   = options.variableDefs;
    fieldNames = fieldnames(varDefs);

    % --- Collect all trial variable names and check duplicates ---
    allVarNames = {};
    for iField = 1:numel(fieldNames)
        fieldName = fieldNames{iField};
        def = varDefs.(fieldName);

        if isfield(def, 'type') && strcmp(def.type, 'trial')
            allVarNames = [allVarNames, def.vars]; %#ok<AGROW>
        end
    end

    % Find duplicates
    [uniqueVars, ~, ic] = unique(allVarNames);
    counts = accumarray(ic, 1);
    dupVars = uniqueVars(counts > 1);
    if ~isempty(dupVars)
        warning('Duplicated trial variable names detected in options.variableDefs:');
        disp(dupVars');
    end

    for iField = 1:numel(fieldNames)
        fieldName = fieldNames{iField};
        def = varDefs.(fieldName);

        % Only process trial-based variables
        if ~isfield(def, 'type') || ~strcmp(def.type, 'trial')
            continue;
        end

        % Read variable-specific beta times (fallback to 0 if missing)
        preTime  = getfieldwithdefault(def, 'betaPreTime', 0);
        postTime = getfieldwithdefault(def, 'betaPostTime', 0);
        
        if preTime == 0
            warning('Variable "%s" has betaPreTime = 0 (no pre-trial extension).', fieldName);
        end
        if postTime == 0
            warning('Variable "%s" has betaPostTime = 0 (no post-trial extension).', fieldName);
        end

        % --- Expand regex/wildcard patterns for trial variables ---
        expandedVars = {};

        for iVar = 1:numel(def.vars)
            thisVar = def.vars{iVar};
            matchIdx = find(~cellfun(@isempty, regexp(obj.bhv.Properties.VariableNames, thisVar, 'once')));
            if ~isempty(matchIdx)
                expandedVars = [expandedVars, obj.bhv.Properties.VariableNames(matchIdx)]; %#ok<AGROW>
            else
                warning('Trial variable "%s" not found in obj.bhv.Properties.VariableNames. Skipping.', thisVar);
            end
        end

        vars = unique(expandedVars);  % remove duplicates

        for iVar = 1:numel(vars)
            varName   = vars{iVar};

            % Initialise with NaNs so unfilled samples don't look like zeros.
            regVector = nan(size(obj.globalTime));

            % Check if variable exists in bhv table
            if ismember(varName, obj.bhv.Properties.VariableNames)
                for iFrame = 1:height(obj.bhv)
                    val   = obj.bhv.(varName)(iFrame);
                    startT = obj.bhv.trialStartTime(iFrame);
                    endT   = obj.bhv.trialEndTime(iFrame);

                    % Skip invalid entries
                    if any(isnan([val, startT, endT]))
                        continue;
                    end
                    % Ensure start <= end
                    if endT < startT
                        tmp = startT; startT = endT; endT = tmp;
                    end

                    % Find closest indices in global time
                    startT_ext = startT - preTime;
                    endT_ext   = endT   + postTime;
                    
                    [~, startTimeIdx] = min(abs(obj.globalTime - startT_ext));
                    [~, endTimeIdx]   = min(abs(obj.globalTime - endT_ext));

                    % Ensure index order
                    if endTimeIdx < startTimeIdx
                        tmp = startTimeIdx;
                        startTimeIdx = endTimeIdx;
                        endTimeIdx = tmp;
                    end

                    % Compute extended indices
                    startIdxExt = startTimeIdx - round(obj.sRate * preTime);
                    endIdxExt   = endTimeIdx   + round(obj.sRate * postTime);
                    
                    % Check if indices are valid
                    if startIdxExt < 1 || endIdxExt > numel(regVector)
                        warning('Extended regressor indices for trial "%s" are out of bounds: [%d, %d]. Clamping to valid range.', ...
                            varName, startIdxExt, endIdxExt);
                    end

                    % Clamp indices to valid range
                    startIdxExt = max(1, startIdxExt);
                    endIdxExt   = min(numel(regVector), endIdxExt);
                    
                    % Fill regressor
                    regVector(startIdxExt:endIdxExt) = val;
                end
            
            % Otherwise, check if it exists in video table
            elseif ismember(varName, obj.vid.Properties.VariableNames)
                nVid = numel(obj.vid.eventTimes);
                for iFrame = 1:height(obj.bhv)
                    startT = obj.bhv.trialStartTime(iFrame);
                    endT   = obj.bhv.trialEndTime(iFrame);

                    % Skip invalid times
                    if any(isnan([startT, endT]))
                        continue;
                    end
                    % Ensure start <= end
                    if endT < startT
                        tmp = startT; startT = endT; endT = tmp;
                    end

                    % Extend with preTime and postTime
                    startT_ext = startT - obj.preTime;
                    endT_ext   = endT   + obj.postTime;

                    % Get closest indices to trial start and end times in video time
                    startIdx = findClosestTimeIdx(obj.vid.eventTimes, startT_ext);
                    endIdx   = findClosestTimeIdx(obj.vid.eventTimes, endT_ext);

                    % Clamp and order indices
                    if isempty(startIdx) || isempty(endIdx) || isnan(startIdx) || isnan(endIdx)
                        continue;
                    end
                    startIdx = max(1, min(nVid, startIdx));
                    endIdx   = max(1, min(nVid, endIdx));
                    if endIdx < startIdx
                        tmp = startIdx; startIdx = endIdx; endIdx = tmp;
                    end

                    % Create trial mask (continuous video variables)
                    trialMask = false(size(obj.vid.eventTimes));
                    trialMask(startIdx:endIdx) = true;
                    trialVals = obj.vid.(varName)(trialMask);

                    % Skip empty or all-NaN trials
                    if isempty(trialVals) || all(isnan(trialVals))
                        continue;
                    end

                    % Compute trial average
                    trialMean = mean(trialVals, 'omitnan');

                    % Get global time indices for regressor filling with extended window
                    startGlobalIdx = findClosestTimeIdx(obj.globalTime, startT - preTime);
                    endGlobalIdx   = findClosestTimeIdx(obj.globalTime, endT   + postTime);

                    % Clamp and order
                    nGlobal = numel(obj.globalTime);
                    if isempty(startGlobalIdx) || isempty(endGlobalIdx) || ...
                            isnan(startGlobalIdx) || isnan(endGlobalIdx)
                        continue;
                    end
                    startGlobalIdx = max(1, min(nGlobal, startGlobalIdx));
                    endGlobalIdx   = max(1, min(nGlobal, endGlobalIdx));
                    if endGlobalIdx < startGlobalIdx
                        tmp = startGlobalIdx; startGlobalIdx = endGlobalIdx; endGlobalIdx = tmp;
                    end

                    % Fill design matrix vector in globalTime
                    regVector(startGlobalIdx:endGlobalIdx) = trialMean;
                end
            else
                warning('Variable "%s" not found in bhv or vid.', varName);
                continue;
            end

            % Replace any remaining NaNs with 0 (keeps downstream size/alignment)
            if any(isnan(regVector))
                regVector(isnan(regVector)) = 0;
            end

            % Quick constant-vector warning (ignoring zeros-only case)
            uq = unique(regVector);
            if numel(uq) == 1
                warning('Regressor trial_%s is constant across globalTime (value=%g).', varName, uq);
            end

            % Assign trial regressor to obj
            obj.(['trial_' varName]) = regVector(:); % Ensure column vector
        end
    end
end
