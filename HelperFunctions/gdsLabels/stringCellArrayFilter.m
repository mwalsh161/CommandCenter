function [fil, ind] = stringCellArrayFilter(arr, reg)
    tf = cellfun(@(str)(~isempty(regexp(str, reg, 'once'))), arr, 'UniformOutput', true);
    fil = arr(tf);
    I = 1:length(arr);
    ind = I(tf);
end