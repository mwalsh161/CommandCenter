function  PathSet(obj,varargin)

for i=1:length(varargin)
    obj.nidaq.WriteDOLines(obj.(sprintf('mirror%i',i)),boolean(varargin{i}));
end

end