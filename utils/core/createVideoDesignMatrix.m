function [vidLabels, vidMat, vidIdx] = createVideoDesignMatrix(obj, options)
    % *createVideoDesignMatrix*: generates a design matrix for video regressors
    % over the non-overlapping, non-expanded time windows (concatenation).
    
    % INPUT:
    % - *obj*: linearEncodeModel instance (for time parameters)
    % - *fullR*: a table containing all regressors
    % - *options*: a configuration struct that is defined at the beginning of
    % the analysis
    
    % OUTPUT:
    % - *vidLabels*: a list of strings showing the regressor names for the
    % vidoPCs
    % - *vidMat*: matrix [frames x number of video regressors]
    % - *vidIdx*: [number of video regressors x 1], each element is the regressor index

vidLabels = {};
vidDataCells = {};

varDefs = options.variableDefs;
varNames = fieldnames(varDefs);

for i = 1:numel(varNames)
    key = varNames{i};
    def = varDefs.(key);
    
    if isfield(def, 'type') && strcmp(def.type, 'continuous')
        vars = def.vars;
        for v = 1:numel(vars)
            varName = vars{v};
            
            if isfield(obj, varName)
                data = obj.(varName);  % get the field first
            
                if isnumeric(data) && size(data,1) > 1 && size(data,2) > 1
                    % Multi-column numeric (like MovementPC [35250×10])
                    for col = 1:size(data,2)
                        vidLabels{end+1} = sprintf('%s%d', varName, col);
                        vidDataCells{end+1} = data(:,col);
                    end
                else
                    % Single column numeric or other types
                    vidLabels{end+1} = varName;
                    vidDataCells{end+1} = data(:,:);
                end
            
            else
                error('Variable "%s" not found as a field in obj.', varName);
            end
        end
    end
end

vidMat = cat(2, vidDataCells{:});
vidIdx = (1:numel(vidLabels))';

end