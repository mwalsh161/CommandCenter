function varargout = uimenu( varargin )
%uimenu wrapper to account for old uimenu not having "Text" property

if verLessThan('matlab','9.3') %"Text" introduced in 2017b
    index = find(strcmpi(varargin,'Text'));
    index(~mod(length(varargin)-index,2)) = []; %remove anything even number from end - not a property name
    for i=1:length(index)
    	varargin{index(i)} = 'Label';
    end
end

varargout = {builtin('uimenu',varargin{:})};
varargout = varargout(1:nargout);