function output = inverse_map(input, mapping)
% Map display name to a field name
input_c = cellify(input);
output = {};
for i=1:numel(input_c)
    input_name = input_c{i};
    
    
    for j=1:numel(mapping)
        key = mapping{j}{1};
        value = cellify(mapping{j}{2});

        % Look for the field name with inverse mapping
        res = cellfun(@(x) strcmp(input_name, x) , value);
        if any(res)
            output{i} = key;
            break;
        end
    end
end
    if ~isempty(output) && ~iscell(input)
        output = output{1};
    end
end
