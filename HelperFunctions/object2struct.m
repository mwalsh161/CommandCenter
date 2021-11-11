function [ st ] = object2struct( obj,ignore,recursive )
%OBJECT2STRUCT Takes visible object properties that are not objects and
%saves to a struct (only if not on MATLABs root)
%   If recursive, will call on any object properties too (default: true)
%   Ignores any property that is listed in the ignore cell array
%   (propegates to all levels of recursion)
%
% Known Bug: Does not look inside cell arrays, so will miss objects stored
% in cell arrays.

st = [];
if isempty(obj)  % null case (important for recursion too!)
    return
end
if nargin < 2
    recursive = true;
    ignore = {};
end
if nargin < 3
    recursive = true;
end

if isobject(obj(1))
    props = properties(obj(1));
else
    props = fields(obj(1));
end
for j = 1:numel(obj)
    for i = 1:numel(props)
        if ~ismember(props{i},ignore)
             % custom objects should be only thing not on matlab's root
            if (~onroot(obj(j).(props{i})) || isstruct(obj(j).(props{i}))) && ~isempty(obj(j).(props{i})) && recursive
                st(j).(props{i}) = object2struct(obj(j).(props{i}),{},recursive);
            else
                st(j).(props{i}) = obj(j).(props{i});
            end
        end
    end
end

end

function tf = onroot(obj)
loc =  which(class(obj));
tf = false;
builtin = 'built-in';
if length(loc) >= length(builtin) && strcmp(loc(1:length(builtin)),builtin)
    tf = true;
elseif length(loc) >= length(matlabroot)
    tf = strcmp(loc(1:length(matlabroot)),matlabroot);
end
end