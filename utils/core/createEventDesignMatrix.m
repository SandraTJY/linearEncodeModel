function [taskLabels, taskMat, taskIdx] = createTaskDesignMatrix(obj, fullR, options)
    % *createTaskDesignMatrix*: constructs time-lagged regressors for
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
preFrames = round(obj.preTime * obj.sRate);
postFrames = round(obj.postTime * obj.sRate);

% --- Collect all event-type vars from options.variableDefs ---
taskLabels = {};
labelTypes = {};
fields = fieldnames(options.variableDefs);
for f = 1:numel(fields)
    key = fields{f};
    def = options.variableDefs.(key);
    if isfield(def, 'type') && strcmp(def.type, 'event')
        vars = def.vars;
        if ~isempty(vars)
            taskLabels = [taskLabels, vars{:}];  % append all vars
            % For each var, assign type as the key (e.g. 'stimulus', 'reward', 'choice')
            labelTypes = [labelTypes, repmat({key}, 1, numel(vars))];
        end
    end
end

% --- Validate labels exist in fullR ---
for i = 1:length(taskLabels)
    label = taskLabels{i};
    if ~ismember(label, fullR.Properties.VariableNames)
        error('Label "%s" not found in fullR table.', label);
    end
end

% --- Expand regressors in the original order ---
taskMat = [];
taskIdx = [];
for i = 1:length(taskLabels)
    label = taskLabels{i};
    % Get time-lagged version of this regressor
    [lagMat, ~] = expandSingleRegressor(fullR{:, label}, preFrames, postFrames);
    % Concatenate
    taskMat = [taskMat, lagMat];
    % Keep track of source regressor index
    taskIdx = [taskIdx; repmat(i, size(lagMat, 2), 1)];
end

end
