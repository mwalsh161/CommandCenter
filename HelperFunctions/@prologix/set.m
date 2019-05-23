function varargout = set(obj,varargin)
% Based on MATLAB\R2018a\toolbox\shared\instrument\@instrument\set.m

% Error if invalid.
if ~all(isvalid(obj))
   error(message('instrument:set:invalidOBJ'));
end
if (length(obj) > 1)
    error(message('instrument:set:nolhswithvector'));
end
if ~nargout
    % set(obj,...)
    varargout = {};
    if nargin == 1
        % set(obj)
        localCreateSetDisplay(obj);
    else
        % set(obj, 'BaudRate');
        % set(obj, 'BaudRate', 4800);
        if length(varargin) == 2 && all(cellfun(@iscell,varargin))
            % set(obj,{'BaudRate','Tag'},{4800,'foo'})
            PN = varargin{1};
            PV = varargin{2};
            if length(PN)~=length(PV)
                error(message('instrument:set:invalidPVPair'));
            end
            for i = 1:length(PN)
                prop_set(obj,PN{i},PV{i});
            end
        elseif length(varargin) == 1 && isstruct(varargin{1})
            % set(obj,struct)
            S = varargin{1};
            props = fieldnames(S);
            for i = 1:length(props)
                prop_set(obj,props{i},S.(props{i}));
            end
        elseif length(varargin) == 1 && ischar(varargin{1})
            localCreateSetDisplay(obj);
        else
            % set(obj,'PropertyName',PropertyValue,...)
            if mod(length(varargin),2)
                error(message('instrument:set:invalidPVPair'));
            end
            for i = 1:2:length(varargin)
                prop_set(obj,varargin{i},varargin{i+1});
            end
        end
    end
else
    % props = set(obj,...)
    A = set(obj.serial);
    % Add in prologix settable properties
    mc = metaclass(obj);
    props = mc.PropertyList(cellfun(@(a)strcmp(a,'public'),{mc.PropertyList.SetAccess}));
    for i = 1:length(props)
        % Only add if it doesn't exist, or more strict default
        % options (this is to prevent clobbering existing options)
        if ~isfield(A,props(i).Name)
            A.(props(i).Name) = {};
        end
        if (props(i).HasDefault && iscell(props(i).DefaultValue))
            % Override value options
            A.(props(i).Name) = props(i).DefaultValue;
        end
    end
    switch nargin
        case 1
            % props = set(obj)    
            % Leave A alone
            varargout{1} = A;
        case 2
            % props = set(obj,'BaudRate')
            % Grab the value of A requested
            if ~ischar(varargin{1})
                % props = set(obj,{'BaudRate','Parity'})
                error(message('instrument:set:invalidPVPair'));
            end
            A = A.(varargin{1});
            varargout{1} = A;
        case 3
            % props = set(obj,'BaudRate',9600)
            set(obj,varargin{:}); % Call without output
            % This will error AFTER setting value just as instrument.set does
    end
end
end

function prop_set(obj,prop,val)
props = properties(obj);
mask = strcmpi(props,prop); % Ignore case
if any(mask)
    obj.(props{mask}) = val; % Use correct case when calling
else
    obj.serial.(prop) = val;
end
end

function localCreateSetDisplay(obj)
% instrument set method calls java setDisplay
error(['Printable display for humans not implemented, assign to struct:',...
    newline, 's = set(obj,...).'])
end