function n = libnargout( libname,FunctionName )
%LIBNARGOUT Given a library and function name, returns number of output args

FunctionProto = libfunctions(libname,'-full');
% Find the line with the right function
b = cellfun(@(a)~isempty(findstr(FunctionName,a)),FunctionProto,'uniformoutput',0); %#ok<FSTR>
FunctionSignature = FunctionProto{[b{:}]};
args = regexp(FunctionSignature,'\((.*)\)','split');
n = numel(strsplit(args{1},' '))-1;
end

