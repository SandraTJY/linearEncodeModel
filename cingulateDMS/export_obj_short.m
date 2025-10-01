%% For exporting only the parts of obj that are needed in Python
output_dir = "C:\Users\stan\Documents\GitHub\linearEncodeModel\cingulateDMS\2025-07-23_1_SAT037\model_10-01_stimOnlickTrace";
mkdir(output_dir)
all_variables = fieldnames(obj);
variables_keep = [];
for v = 1:numel(all_variables)
    if (~startsWith(all_variables(v), 'cell') || startsWith(all_variables(v), 'cell50')) && ~startsWith(all_variables(v), 'crossVa') % Do not export all the cell-specific traces, but keep regression results in crossVal
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

save(fullfile(output_dir, 'obj.mat'), '-struct','obj_export');
save(fullfile(output_dir, 'crossVal.mat'),'-struct','crossVal_export');