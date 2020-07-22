function [ devs ] = GetPorts(FriendlyName)
%GETPORTS Returns cell array of available ports, or the port that matches FriendlyName
%   Adapted from MATLAB Central Post: How can I identify COM port devices on Windows

if ~ispc
    error('GetPorts works for windows machines only')
end

%% Find connected serial devices and clean up the output
Skey = 'HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM';
[~, list] = dos(['REG QUERY ' Skey]);
list = textscan(list,'%s','delimiter',' '); list = list{1};
coms = {};
for i = 1:numel(list)
  if length(list{i})>3 && strcmp(list{i}(1:3),'COM')
  	coms{end+1} = list{i};
  end
end
%% Find all installed USB devices entries and clean up the output
key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\';
[~, vals] = dos(['REG QUERY ' key ' /s /f "FriendlyName" /t "REG_SZ"']);
vals = textscan(vals,'%s','delimiter','\t');
vals = cat(1,vals{:});
out = {};
% Find all friendly name property entries
for i = 1:numel(vals)
  if strcmp(vals{i}(1:min(12,end)),'FriendlyName')
      out{end+1} = vals{i};
  end
end
%% Compare friendly name entries with connected ports and generate output
devs = {};
coms
for i = 1:numel(coms)
  match = strfind(out,[coms{i},')']);
  ind = 0;
  for j = 1:numel(match)
      if ~isempty(match{j})
          ind = j;
      end
  end
  if ind ~= 0
      com = coms{i};
      name = out{ind}(27:end-(3+length(com)));
      if nargin == 1 && contains(name,FriendlyName)
          devs = com;
          return
      end
      com = coms{i};
      devs{end+1,1} = com;
      devs{end,2} = name;
  end
  if nargin == 1
      % No match
      devs = [];
  end
end
end

