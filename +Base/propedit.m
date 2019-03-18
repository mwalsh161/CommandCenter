function fig = propedit( obj )
%PROPEDIT - open property manager for obj for SetAccess=public properties

meta = metaclass(obj);
props = meta.PropertyList;
% Filter on SetAccess
setAccess = {props.SetAccess};
map = cellfun(@(a)isequal(a,'public'),setAccess);
props = props(map);
% Filter on Hidden
props = props(~[props.Hidden]);

fig = figure('name','Manager Property Editor','HandleVisibility','Callback',...
          'IntegerHandle','off','menu','none','numbertitle','off');
fig.Position(3:4) = [300 400];
t = uitable(fig);
t.ColumnName = {'Property','Value'};
t.RowName = [];
t.ColumnEditable = [false, true];
d = cell(0,2);
for i = 1:length(props)
    d(end+1,:) = {props(i).Name,obj.(props(i).Name)};
end
t.Data = d;
t.ColumnWidth = {149 148};
t.Units = 'normalized';
t.Position = [0 0 1 1];
t.UserData = obj;
t.CellEditCallback = @edit;
end

function edit(hobj,eventdata)
val = eventdata.NewData;
prop = hobj.Data{eventdata.Indices(1),1};
hobj.UserData.(prop) = val;
hobj.Data{eventdata.Indices(1),2} = hobj.UserData.(prop);
end

