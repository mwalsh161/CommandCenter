function result = isfile(fileName)
%ISFILE Summary of this function goes here
%   Detailed explanation goes here

if verLessThan('matlab','9.3') % 2017B
    file=java.io.File(fileName);
    result = file.isFile();
else
    result = builtin('isfile',fileName);
end

end

