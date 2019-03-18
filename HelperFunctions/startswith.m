function [ tf ] = startswith( string,substring )
%STARTSWITH See if string starts with substring
len = numel(substring);
if len > numel(string)
    tf = false;
    return
end
tf = strcmp(substring,string(1:len));
end

