function [ f ] = EditChannelDelays()
%CHANNELDELAYS Summary of this function goes here
%   Detailed explanation goes here
f = findall(0,'name',mfilename);
if isempty(f)
    f = figure('visible','off','name',mfilename,'numbertitle','off','MenuBar','none','resize','off');
end
cnames = {'Delay (ns)'};
entries = getpref('channel');
rownames = fieldnames(entries);
order = cellfun(@(a)str2double(a(end)),rownames);
[~,order] = sort(order);
rownames = rownames(order);
delays = zeros(numel(rownames),1);
for i = 1:numel(rownames)
    delays(i) = getpref('channel',rownames{i});
end
t = uitable(f,'ColumnName',cnames,'RowName',rownames,'Data',delays,'ColumnEditable',[true],'CellEditCallback',@updated);
t.Position(3) = t.Extent(3);
t.Position(4) = t.Extent(4);
f.Position(3) = t.Position(1)*2+t.Position(3);
f.Position(4) = t.Position(2)*2+t.Position(4);
f.Visible = 'on';
end

function updated(~,eventdata)
name = eventdata.Source.RowName{eventdata.Indices(1)};
setpref('channel',name,eventdata.NewData)
end