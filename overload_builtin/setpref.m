function setpref( varargin )
%SETPREF Safe version of MATLAB's setpref for CommandCenter
[ST,~] = dbstack;
if numel(ST) < 2
    cont = input(sprintf('CommandCenter uses these prefs for all modules.\nDirect modification can cause unexpected behavior.\nContinue Y/N [N]? '),'s');
else % Must be called from another function
    cont = 'y';
end
if numel(cont)>0 && strcmpi(cont(1),'y')
    func_path = fullfile(matlabroot, 'toolbox','matlab','uitools');
    wrn = warning('off','MATLAB:dispatcher:nameConflict');
    oldPath = cd(func_path);
    err = [];
    try
        setpref(varargin{:})
    catch err
    end
    cd(oldPath)
    warning(wrn.state,'MATLAB:dispatcher:nameConflict');
    if ~isempty(err)
        rethrow(err)
    end
end
end