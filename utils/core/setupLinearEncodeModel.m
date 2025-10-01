function obj = setupLinearEncodeModel(obj, expRef, options)
    % CONSTRUCTOR CLASS: a function that helps to initalise an instance
    % of a new object (for here, this is the the respective mouse name [mouseName],
    % experimental session reference [expRef], and the motion data + experimental 
    % time in global time scale [motionData]. This function first
    % define file and data paths, load behavioural and neural
    % data for the session, define global time axis (according to the task data), 
    % interpolate neural data and video PCs data with the respective time 
    % frames in the global time axis 

    % INPUT:
    % - *expRef*: the experiment session reference in *string* format (e.g., '2023-06-13_1_AMR007')
    % - *motionData*: the data table that contains two variables in *table*
    % format: 1) the motion PCs that was extracted from facemap, and 2)
    % the callibrated event times in aligned global timeline (e.g., in sync 
    % with the neural and behavioural data)that was extracted (e.g., motionData)
    
    % OUTPUT:
    % - *obj* (could be of any name your have defined in your procedural
    % script): a class instance that contains 1) data table, or 2) empty regressor container
    % for all the necessary information for calling subsequent functions in *object* 
    % format (e.g., mouse name, data roots, behavioural and neural data tables)

% --- Basic Metadata Setup ---
obj.expRef = expRef;
obj.sRate = options.sRate;
obj.firstTrialEvent = options.firstTrialEvent;
obj.lastTrialEvent = options.lastTrialEvent;

% --- Store Variable Definitions ---
obj.variableDefs = options.variableDefs;

% --- Trial count information ---
obj.bhvTrialCnt = height(obj.bhv);

% --- Global Time Axis ---
obj.globalStartTime = min(obj.bhv.(obj.firstTrialEvent)) - 5; % Padding - making sure the global timeline encompasses all events
obj.globalEndTime   = max(obj.bhv.(obj.lastTrialEvent)) + 20; % Padding - making sure the global timeline encompasses all events;
obj.globalTime      = obj.globalStartTime : 1/obj.sRate : obj.globalEndTime;
nT = numel(obj.globalTime);

% --- Neural Interpolation ---
neuralTime = obj.neural.(obj.variableDefs.neural.timeRef); 
obj.neuralInterpolated = struct();  % holds any interpolated neural signal

neuralVars = obj.variableDefs.neural.vars;  % e.g., {'cell.*'}
neuralFieldNames = fieldnames(obj.neural);

for i = 1:numel(neuralVars)
    thisVarPattern = neuralVars{i};
    
    % --- Find matches in obj.neural fields ---
    matchIdx = find(~cellfun(@isempty, regexp(neuralFieldNames, thisVarPattern, 'once')));
    if isempty(matchIdx)
        warning('Neural variable pattern "%s" did not match any fields in obj.neural. Skipping.', thisVarPattern);
        continue;
    end
    
    for j = 1:numel(matchIdx)
        varName = neuralFieldNames{matchIdx(j)};
        
        % Interpolate onto global time
        obj.(varName) = interp1(neuralTime, obj.neural.(varName), obj.globalTime, 'linear', 'extrap');
        obj.neuralInterpolated.(varName) = obj.(varName);  % store a copy in neuralInterpolated
    end
end

% % --- Continuous Vid Data Interpolation ---
% if isfield(obj, 'vid') && ~isempty(obj.vid) && isfield(options.variableDefs, 'vid')
%     % Video PCs
%     obj = interpolateContinuous(obj, obj.variableDefs.vid, 'vid', nT);
% 
%     % Keypoints
%     obj = interpolateContinuous(obj, obj.variableDefs.keypoint, 'vid', nT);
% end

% --- Other Continuous data interpolation ---
varNames = fieldnames(options.variableDefs);
hasContinuous = any(cellfun(@(f) strcmpi(options.variableDefs.(f).type, 'continuous'), varNames));
if hasContinuous
    for i = 1:numel(varNames)
        varType = varNames{i};
        def = options.variableDefs.(varType);
        
        if strcmp(def.type, 'continuous')
            % --- Expand regex/wildcard patterns for continuous variables ---
            expandedVars = {};

            objFields = fieldnames(obj);
            for j = 1:numel(def.vars)
                thisVar = def.vars{j};
                matchIdx = find(~cellfun(@isempty, regexp(objFields, thisVar, 'once')));
                if ~isempty(matchIdx)
                    expandedVars = [expandedVars, objFields(matchIdx)]; %#ok<AGROW>
                else
                    warning('Continuous variable "%s" not found in obj fields. Skipping.', thisVar);
                end
            end
            % Pull out the unique continuous variables (no duplicates)
            vars = unique(expandedVars);
            for j = 1:numel(vars)
                varName = vars{j};
                if isfield(obj, varName)
                    % data = obj.(varName);
                    obj = interpolateContinuous(obj, obj.variableDefs.(varName), varName, nT);
                    disp("Interpolated continuous variable " + varName + " and saved in obj")
                else
                    warning('Continuous variable "%s" not found in obj fields. Not interpolating.', varName);
                end
            end
        end
    end
end

