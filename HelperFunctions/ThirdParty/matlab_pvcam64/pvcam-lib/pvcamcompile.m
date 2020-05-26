function pvcamcompile
    try
%         mex pvcam64.lib pvcamacq.c pvcamclose.c pvcamget.c pvcamopen.c pvcamppselect.c pvcamppshow.c pvcamset.c pvcamshutter.c pvcamutil.c
        mex pvcam64.lib pvcamopen.c pvcamutil.c
        mex pvcam64.lib pvcamacq.c pvcamutil.c
    catch err
        disp( "MATLAB Compiler must be installed, along with the MinGW add-on (Home > Enviroment > Get Add-On > Search 'MinGW')");
        rethrow(err);
    end
end