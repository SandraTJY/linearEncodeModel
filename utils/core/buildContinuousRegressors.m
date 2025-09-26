function obj = buildContinuousRegressors(obj, options)
    % *buildContinuousRegressors*: a function that extracts video PCs 
    % regressors together into a non-time shifted design matrix. Only
    % process multiple column/ row data (e.g., PCs), but keep the other
    % 1-dimensional data intact.
    
    % INPUT:
    % - *obj*: (can be kept empty) the *object instance* of the class linearEncodeModel
    % that was previously created, in MATLAB this is just a syntax
    % to call the function as it belongs to the method of the class
    % linearEncodeModel()
    % - *optipns* : the configuration struct that is defined at the
    % beginning of the analysis

    % OUTPUT:
    % - *obj*: updates the obj struct with individual types of video PCs
    % in a separate subfield in the obj struct, relabelled in separate
    % numbers (e.g., MotionPC -> MotionPC1, MotionPC2, ..., MotionPC100)

    variableTypes = fieldnames(options.variableDefs);
    
    % --- Collect all continuous variable names and check duplicates ---
    allVarNames = {};
    for i = 1:numel(variableTypes)
        varType = variableTypes{i};
        def = options.variableDefs.(varType);
        if strcmp(def.type, 'continuous')
            allVarNames = [allVarNames, def.vars]; %#ok<AGROW>
        end
    end

    % Find duplicates
    [uniqueVars, ~, ic] = unique(allVarNames);
    counts = accumarray(ic, 1);
    dupVars = uniqueVars(counts > 1);
    if ~isempty(dupVars)
        warning('Duplicated continuous variable names detected in options.variableDefs:');
        disp(dupVars');
    end

    for i = 1:numel(variableTypes)
        varType = variableTypes{i};
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
            
            vars = unique(expandedVars);

            for j = 1:numel(vars)
                varName = vars{j};
                
                if isfield(obj, varName)
                    data = obj.(varName);

                    % Check if data is a matrix
                    if ~ismatrix(data)
                        warning('Variable "%s" is not a 2D matrix and will be ignored.', varName);
                        continue;
                    end

                    % Check if data has more than 2 dimensions
                    if ndims(data) > 2
                        warning('Variable "%s" has more than 2 dimensions (%dD) and will be ignored.', varName, ndims(data));
                        continue;
                    end

                    % Only process multi-column matrices (more than 1 row/ column)
                    if size(data, 1) > 1 && size(data, 2) > 1
                        for k = 1:size(data, 2) % the first column should be the event time series
                            newField = sprintf('%s%d', varName, k);
                            obj.(newField) = data{:,k}';
                        end
                    end
                else
                    warning('Variable "%s" listed in options.variableDefs but not found in obj.', varName);
                end
            end
        end
    end
end
