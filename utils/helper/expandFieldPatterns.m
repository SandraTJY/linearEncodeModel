function matchedFields = expandFieldPatterns(obj, patterns)
% *expandFieldPatterns*: A helper function that helps to identify field
% names from the wildcard name tag from options.variabledefs
    objFields = fieldnames(obj);
    matchedFields = {};
    for i = 1:numel(patterns)
        matches = objFields(~cellfun(@isempty, regexp(objFields, patterns{i}, 'once')));
        matchedFields = [matchedFields; matches];
    end
end
