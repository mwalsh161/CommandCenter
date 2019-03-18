function [ tf ] = EndsWith( str,suffix )
%ENDSWITH Determine if a string ends with suffix.
    % Return true if the string ends in the specified suffix, otherwise
    % false.

n = length(suffix);
if length(str) < n
    tf =  false;
else
    tf = strcmp(str(end-n+1:end), suffix);
end

end

