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
nprops = length(props);
d = cell(nprops,2);
for i = 1:nprops
    d(i,:) = {strrep(props(i).Name,'_',' '), obj.(props(i).Name)};
end
fig = figure('name','Manager Property Editor','HandleVisibility','Callback',...
          'IntegerHandle','off','menu','none','numbertitle','off',...
          'Resize','off','visible','off');
% Calculate desired columnwidths
[~,I] = max(cellfun(@length,d(:,1)));
temp = uicontrol(fig,'style','text','string',d{I,1});
wid = temp.Extent(3);
delete(temp);

t = uitable(fig,'ColumnName', {'Property', 'Value'},...
                'RowName', [],...
                'ColumnEditable', [false, true],...
                'Data', d,...
                'ColumnWidth', {wid,'auto'},...
                'UserData', obj,...
                'CellEditCallback', @edit,...
                'Units', 'Pixels');

t.Position(3:4) = [t.Extent(3), min(500, t.Extent(4))];
try % Backwards compatible with older MATLAB
    outerpos = t.OuterPosition;
catch
    outerpos = t.Position;
end
% Add in margin
outerpos(3) = outerpos(1)*2 + outerpos(3);
outerpos(4) = outerpos(2)*2 + outerpos(4);
fig.Position(3:4) = [max(300,outerpos(3)) outerpos(4)];
% Recenter table
t.Position(1) = (fig.Position(3) - t.Position(3))/2;
fig.Visible = 'on';
end

function edit(hobj,eventdata)
val = eventdata.NewData;
prop = hobj.Data{eventdata.Indices(1),1};
hobj.UserData.(prop) = val;
hobj.Data{eventdata.Indices(1),2} = hobj.UserData.(prop);
end

