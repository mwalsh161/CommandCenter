function A = get(obj,prop)
% struct = get(obj)
% value = get(obj,'BaudRate')

% Error if invalid.
if ~all(isvalid(obj))
    error(message('instrument:set:invalidOBJ'));
end
if (length(obj) > 1)
    error(message('instrument:set:nolhswithvector'));
end

% Build full struct
% struct = get(obj)
A = get(obj.serial);
% Add in prologix settable properties
mc = metaclass(obj);
props = mc.PropertyList(cellfun(@(a)strcmp(a,'public'),{mc.PropertyList.GetAccess}));
for i = 1:length(props)
    % Overwrite all "overloaded" properties
    A.(props(i).Name) = obj.(props(i).Name);
end

if nargin == 2
    if ischar(prop)
        % value = get(obj,'BaudRate')
        A = prop_get(obj,prop);
    elseif iscell(prop) && all(cellfun(@ischar,prop))
        % value = get(obj,{'BaudRate','tag'})
        A = cellfun(@(p)prop_get(obj,p),prop,'uniformoutput',false);
    else
        error('prop must be a char array or cell of char arrays')
    end
end
end

function val = prop_get(obj,prop)
props = properties(obj);
mask = strcmpi(props,prop); % Ignore case
if any(mask)
    val = obj.(props{mask}); % Use correct case when calling
else
    val = obj.serial.(prop);
end
end