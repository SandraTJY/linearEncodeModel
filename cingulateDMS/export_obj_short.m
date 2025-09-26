%% For exporting only the parts of obj that are needed in Python

all_variables = fieldnames(obj);
variables_keep = [];
for v = 1:numel(all_variables)
    if ~startsWith(all_variables(v), 'cell') && ~startsWith(all_variables(v), 'crossVa') % Do not export all the cell-specific traces, but keep regression results in crossVal
        variables_keep = [variables_keep all_variables(v)];
    end
end
disp(variables_keep);
obj_export = struct();
for v = 1:numel(variables_keep)
    obj_export.(variables_keep{v}) = obj.(variables_keep{v});
end

%% Also export crossVal as its own file
crossVal_export = obj.crossVal;
% 
