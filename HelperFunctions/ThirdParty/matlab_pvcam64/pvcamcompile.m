function pvcamcompile
    assert(exist('HelperFunctions', 'dir') == 7, 'Should be called from CommandCenter directory');
    old = cd(['HelperFunctions' filesep 'ThirdParty' filesep 'matlab_pvcam64' filesep 'pvcam-lib']);
        
    try
%         mex pvcam64.lib pvcamacq.c pvcamclose.c pvcamget.c pvcamopen.c pvcamppselect.c pvcamppshow.c pvcamset.c pvcamshutter.c pvcamutil.c
%         mex pvcam64.lib pvcamacq.c pvcamclose.c pvcamget.c pvcamopen.c pvcamppshow.c pvcamset.c pvcamshutter.c pvcamutil.c
        fnames = {'pvcamacq.c', 'pvcamclose.c', 'pvcamget.c', 'pvcamopen.c', 'pvcamppshow.c', 'pvcamset.c', 'pvcamshutter.c' };
%         , 'pvcamppselect.c'
        
        for str = fnames
            disp(['Attempting to build ' str{1} '!']);
            mex('pvcam64.lib', str{1}, 'pvcamutil.c')
        end
        
%         mex pvcam64.lib pvcamacq.c  pvcamutil.c
%         mex pvcam64.lib pvcamopen.c pvcamutil.c
%         mex pvcam64.lib pvcamopen.c pvcamutil.c
        
        cd(old);
    catch err
        disp( "MATLAB Compiler must be installed, along with the MinGW add-on (Home > Enviroment > Get Add-On > Search 'MinGW')");
        cd(old);
        rethrow(err);
    end
end