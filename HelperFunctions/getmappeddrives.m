function drives = getmappeddrives()
% getmappeddrives returns Nx2 cell array with mapped drive info
%   column 1 is drive letter
%   column 2 is remote

% Short-circuit if not PC
if ~ispc()
    drives = '\';
    return
end

[~,out] = system('net use');
out = strsplit(out,newline);
out = out(4:end-2); % Crop output
drives = cell(length(out),2);
rm = [];
for i = 1:length(out)
    try
        line = strsplit(out{i},'  ');
        drives{i,1} = strip(line{2});
        drives{i,2} = strip(line{3});
    catch
        rm(end+1) = i;
    end
end
drives(rm) = [];
end