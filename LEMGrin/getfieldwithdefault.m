function structa_field = getfieldwithdefault(structa, fieldname, default_value)
    if ismember(fieldname, fieldnames(structa))
        structa_field = structa.(fieldname);
    else
        structa_field = default_value;
    end
end