function [result,tf] = str2num(expression) %#ok<INUSD>
%STR2NUM Wraps MATLAB's str2num in evalc to avoid stdout
%   NOTE: str2num does input validation that is easiest to reuse by calling
%   str2num in evalc instead of just the expression
%   NOTE: this does not introduce any further security vectors

func_path = fullfile(matlabroot, 'toolbox','matlab','strfun');
wrn = warning('off','MATLAB:dispatcher:nameConflict');
oldPath = cd(func_path);

try
    [~,result,tf] = evalc('str2num(expression)');
catch err
end

cd(oldPath)
warning(wrn.state,'MATLAB:dispatcher:nameConflict');
if exist('err','var')
    rethrow(err)
end
end

    
