function varargout = munlockAll()
%MUNLOCKALL Unlocks all m files locked inmem
%   Returns files that were unlocked. If no output requested, fprintf is
%   used.

LoadedM = inmem;
mask = false(1,length(LoadedM));
for i = 1:length(LoadedM)
    if mislocked(LoadedM{i})
        munlock(LoadedM{i});
        mask(i) = true;
        if ~nargout
            fprintf('%s\n',LoadedM{i})
        end
    end
end
if nargout
    varargout{1} = LoadedM(mask);
end
end

