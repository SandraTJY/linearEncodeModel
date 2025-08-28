function [taskLabels, taskMat, taskIdx] = createEventDesignMatrix(obj, fullR, options)
    % *createEventDesignMatrix*: constructs time-lagged regressors for
    % stim-, reward-, and choice-related signals separately in the entire timeline.
    
    % INPUT:
    % - *obj*: class object (can be empty if used outside class context)
    % - *fullR*: table of raw behavioral regressors (not time-lagged)
    % - *options*: the configuration struct that was defined at the beginning o
    % of the analysis
    
    % OUTPUT:
    % - *taskLabels*: a list of strings of task (event) regressors
    % - *taskMat*: combined padded time-lagged design matrix [frames x total_lags]
    % - *taskIdx*: vector indexing which original regressor (by position) each column belongs to

% --- Define frame windows ---
fields = fieldnames(options.variableDefs);
taskLabels = {};
preFramesPerVar = [];
postFramesPerVar = [];

% --- Expand wildcards and collect beta times ---
for f = 1:numel(fields)
    key = fields{f};
    def = options.variableDefs.(key);
    
    if isfield(def, 'type') && strcmp(def.type, 'event')
        vars = def.vars;

        if isempty(vars)
            continue; 
        end
        
        for iVars = 1:numel(vars)
            pattern = vars{iVars};
            matchIdx = find(~cellfun(@isempty, regexp(fullR.Properties.VariableNames, pattern, 'once')));
            
            if isempty(matchIdx)
                warning('No matches found for pattern "%s" in fullR table.', pattern);
                continue;
            end

            matches = fullR.Properties.VariableNames(matchIdx);
            
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
    end
end

% --- Build lagged regressors ---
taskMat = [];
taskIdx = [];

for iLabel = 1:length(taskLabels)
    label = taskLabels{iLabel};
    preFrames  = preFramesPerVar(iLabel);
    postFrames = postFramesPerVar(iLabel);
    
    [lagMat, ~] = expandSingleRegressor(fullR{:, label}, preFrames, postFrames);
    
    taskMat = [taskMat, lagMat];
    taskIdx = [taskIdx; repmat(iLabel, size(lagMat, 2), 1)];
end
end
