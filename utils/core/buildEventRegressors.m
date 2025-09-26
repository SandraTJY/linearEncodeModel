function obj = buildEventRegressors(obj, options)
    % *buildEventRegressors*: a function that help to load the
    % regressors and compile them into a *non-time shifted, non-expanded*
    % design matrix.
    
    % INPUT:
    % - *obj* (can be kept empty): the object instance from the linearEncodeModel class that was
    % created previously, in MATLAB this is just a syntax
    % to call the function as it belongs to the method of the class
    % linearEncodeModel()
    % - *options*: the configuration struct that is defined at the
    % beginning of the analysis
    
    % OUTPUT:
    % - *obj* (can be other names that you have defined previously):
    % the object instance from the linearEncodeModel class that has
    % seperate subfields that contains the defined behavioural regressors
    % of the non-time shifted design matrix

 arguments
        obj struct
        options struct
    end

    % Basic validation
if ~isfield(options, 'variableDefs')
    error('Missing field: options.variableDefs');
end

% --- Collect all variable names and check for duplicates ---
allVarNames = {};  % initialise empty list
eventGroups = fieldnames(options.variableDefs);

for iG = 1:numel(eventGroups)
    groupName = eventGroups{iG};
    groupDef = options.variableDefs.(groupName);

    % Only consider groups of type 'event'
    if isfield(groupDef, 'type') && strcmp(groupDef.type, 'event')
        allVarNames = [allVarNames, groupDef.vars];
    end
end

% Find duplicates
[uniqueVars, ~, ic] = unique(allVarNames);
counts = accumarray(ic, 1);
dupVars = uniqueVars(counts > 1);

if ~isempty(dupVars)
    warning('Duplicated variable names detected in options.variableDefs:');
    disp(dupVars');
end

% --- Process each event group ---
for iG = 1:numel(eventGroups)
    groupName = eventGroups{iG};
    groupDef = options.variableDefs.(groupName);

    if ~isfield(groupDef, 'type') || ~strcmp(groupDef.type, 'event')
        continue;  % skip non-event groups
    end

    % Handle vars
    vars = groupDef.vars;
    expandedVars = {};
    for iVars = 1:numel(vars)
        thisVar = vars{iVars};

        % Expand wildcard using regex against obj.bhv columns
        matchIdx = find(~cellfun(@isempty, regexp(obj.bhv.Properties.VariableNames, thisVar, 'once')));
        if ~isempty(matchIdx)
            expandedVars = [expandedVars, obj.bhv.Properties.VariableNames(matchIdx)];
        else
            warning('Variable pattern "%s" did not match any columns in obj.bhv. Skipping.', thisVar);
        end
    end
    vars = unique(expandedVars);  % remove duplicates

    if isempty(vars)
        continue; % skip group if no vars matched
    end

    % Handle timeRef
    timeRef = groupDef.timeRef;
    % if ~iscell(timeRef)
    %     timeRef = {timeRef};
    % end
    % 
    % % Check each timeRef exists in bhv
    % validTimeRef = {};
    % for t = 1:numel(timeRef)
    %     if ismember(timeRef{t}, obj.bhv.Properties.VariableNames)
    %         validTimeRef{end+1} = timeRef{t};
    %     else
    %         warning('Time reference "%s" not found in obj.bhv. Skipping.', timeRef{t});
    %     end
    % end
    % 
    % if isempty(validTimeRef)
    %     warning('No valid timeRefs found for group "%s". Skipping.', groupName);
    %     continue;
    % end
    % 
    % % If more than one valid timeRef, throw an error
    % if numel(validTimeRef) > 1
    %     error('Group "%s" has more than one valid timeRef. Only the first one will be used: "%s".', ...
    %         groupName, validTimeRef{1});
    % end
    % 
    % % Use the first (and only) valid timeRef
    % timeRef = validTimeRef{1};

    % --- Build regressors ---
    for iVars = 1:numel(vars)
        varName = vars{iVars};
        fieldName = matlab.lang.makeValidName(varName);
        regVector = zeros(numel(obj.globalTime), 1);

        for iTrial = 1:height(obj.bhv)
            val = obj.bhv.(varName)(iTrial);
            eventTime = obj.bhv.(timeRef)(iTrial);

            if isnan(val) || isnan(eventTime)
                continue;
            end

            [~, timeIdx] = min(abs(obj.globalTime - eventTime));
            regVector(timeIdx) = val;
        end

        % Save into obj
        obj.(fieldName) = regVector;
    end
end
end
