function fullR = getEventDesignMatrix(obj, options)
    % *getEventDesignMatrix*: a function that combines all behavioural together
    % into a non-time shifted design matrix (concatenation). Essential to
    % separate it with video or trial regressors as this needs to be
    % expanded
    
    % INPUT:
    % - *obj*: (can be kept empty) the *object instance* of the class linearEncodeModel
    % that was previously created, in MATLAB this is just a syntax
    % to call the function as it belongs to the method of the class
    % linearEncodeModel()
    % - *options*: the configuration struct that is defined at the
    % beginning of the analysis

    % OUTPUT:
    % - *fullR*: a *table* that contains the non-time shifted
    % behavioural and video PCs regressors.

varDefs = options.variableDefs;
nTimepoints = numel(obj.globalTime);
allData = {};
allNames = {};

defNames = fieldnames(varDefs);

objFields = fieldnames(obj); % All possible fields in obj

for i = 1:numel(defNames)
    def = varDefs.(defNames{i});

    % Only event variables
    if ~ismember(def.type, {'event'})
        continue;
    end

    for j = 1:numel(def.vars)
        pattern = def.vars{j};

        % Match all obj fields using regex pattern
        matchIdx = find(~cellfun(@isempty, regexp(objFields, pattern, 'once')));
        matchingFields = objFields(matchIdx);

        for k = 1:numel(matchingFields)
            fName = matchingFields{k};
            dataCol = obj.(fName);

            % Only include column vector of correct length
            if isvector(dataCol) && numel(dataCol) == nTimepoints
                if ~ismember(fName, allNames)
                    allData{end+1} = double(dataCol(:)); % ensure column vector
                    allNames{end+1} = fName;
                end
            end
        end
    end
end

% Combine into table
fullR = table(allData{:}, 'VariableNames', allNames);
end
