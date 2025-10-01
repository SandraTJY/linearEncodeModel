function obj = interpolateContinuous(obj, defStruct, dataSource, nT)
% *interpolateContinuous*: a helper function for handling continuous data interpolation
% in setupLinearEncodeModel.

    if isempty(defStruct) || ~isstruct(defStruct), return; end

    % Get time reference
    timeRefName = defStruct.timeRef{1};
    if ismember(timeRefName, obj.(dataSource).Properties.VariableNames)
        eventTimes = obj.(dataSource).(timeRefName);
    else
        warning('Time reference "%s" not found in %s', timeRefName, dataSource);
        return;
    end

    % Loop over variables and interpolate
    for i = 1:numel(defStruct.vars)
        varName = defStruct.vars{i};
        
        % Check the data exists
        if istable(obj.(dataSource))
            if ~ismember(varName, obj.(dataSource).Properties.VariableNames)
                warning('Variable "%s" not found in %s', varName, dataSource);
                continue;
            end
            y = obj.(dataSource).(varName);
        else
            if ~isfield(obj.(dataSource), varName)
                warning('Variable "%s" not found in %s', varName, dataSource);
                continue;
            end
            y = obj.(dataSource).(varName);
        end
        
        % Interpolate and store in top-level obj
        if numel(y) ~= nT
            interp_y = interp1(eventTimes, y, obj.globalTime, 'linear', 'extrap');
            % Transpose if interp_y is in wrong shape
            if size(interp_y, 1) ~= nT
                interp_y = reshape(interp_y, [size(interp_y, 2), size(interp_y, 1)]);
            end
            obj.(varName) = interp_y;
        else
            obj.(varName) = y;
        end
    end
end

