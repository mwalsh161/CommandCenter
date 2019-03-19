function [ h ] = uicontrolgroup(props, callback,varargin)
%uicontrolgroup UI tool to help create editable groups
%   editable elements can be a popup or textedit
%   Inputs:
%       props: list of structs. Must have following fields:
%           name - string of property name (used as tag for uicontrol
%               handle)
%           display_name - name displayed in GUI (e.g. also specify units)
%               Can be empty strings as well, in which case name is used.
%           default - for text edits, just a  string. for popup, should be
%               an integer between 1 and length of options where
%               options{default} is the displayed value
%           options - for text edit should be empty. For popup should be
%               cell array of strings.
%           style - whether property is of type: edit, popup or text
%       callback - function handle. executed when anything is edited
%       @callback(handle, eventdata)
%       the first arg is the handle to the uicontrol that was edited.
%       Remember the tag is the property name.
%       eventdata is a struct with the following fields
%           previous_value: the value before editing
%           new_value: the value that was entered
%       -This function can optionally return the actual value set which
%       will update the ui element accordingly.
%       varargin gets passed directly to panel that is created to house
%           everything (tip: specify parent here)
%           uicontrolgroup will use UserData as a line height specification
%           in units of characters.
%   Outputs:
%       h: handle to panel that is created to contain everything
%           Populates h.UserData with a list of uicontrol handles
%
%   Notes: the position of the labels is determined by the longest one, and
%   the remainder of the space is for the uicontrol.  The width of the
%   parent will not be changed, but the length can be.
%
%   Known Issues: Can't update the callback after function call

h = uipanel('visible','off',varargin{:});

h.Units = 'characters';
width = h.InnerPosition(3);
border = 1;%changed from 5
spacing = 1.5;
if isnumeric(h.UserData) && length(h.UserData(:))==1
    spacing = h.UserData;
end
num_lines = length(props);

label_widths = Inf(1,length(props));
for i = 1:length(props)
    prop = props{i};
    if ~isfield(prop,'display_name') || isempty(prop.display_name)
        display = prop.name;
    else
        display = prop.display_name;
    end
    tag = prop.name;
    h_text = uicontrol(h,'style','text',...
        'string',[display ':'],...
        'horizontalalignment','right',...
        'units','characters',...
        'position',[border spacing*(num_lines-i) 30 1.25],...  % Only height matters right now
        'tag',[tag '_label']);
    label_widths(i) = h_text.Extent(3);
    ui = uicontrol(h,'units','characters',...
        'horizontalalignment','left',...
        'position',[border spacing*(num_lines-i) 30 1.25],...  % Only height matters right now
        'tag',tag,...
        'callback',@mycallback,...
        'UserData',struct('callback',callback,'value',[],'Tag',tag));
    
    switch prop.style  %if you want to add more use cases of prop.style make sure to edit myfunction correctly
        
        case 'edit'
            % Edit
            ui.Style = 'edit';
            ui.String = prop.default;
            ui.UserData.value = prop.default;
        case 'popup'
            % Popup
            ui.Style = 'popup';
            ui.String = prop.options;
            ui.Value = prop.default;
            ui.UserData.value =prop.options{prop.default};
        case 'text'
            ui.Style = 'text';
            ui.String = prop.default;
    end
    if isempty(callback)  % Remove callback if none specified
        ui.Callback = '';
    end
    ui_labels(i) = h_text;
    ui_handles(i) = ui;
end
% Fix horizontal position now that we know the extent for each item
label_widths = max(label_widths);
for i = 1:length(props)
    ui_labels(i).Position(3) = label_widths;
    ui_handles(i).Position(1) = label_widths+border;
    try
        ui_handles(i).Position(3) = width-(label_widths+border*2);
    catch
        ui_handles(i).Position(3) =0;
    end
end

h.Position(4) = spacing*num_lines;
h.UserData = struct('handles',ui_handles,'update',@updateGUI);
h.BorderType='None';
h.Visible = 'on';
end

function updateGUI(hObj,name,val)
% hObj: handle to panel
% name: name of property (tag)
% val: val (as number)
h = findall(hObj.UserData.handles,'tag',name);
assert(~isempty(h),sprintf('Could not find property %s in %s',name,mfilename))
if strcmp(h.Style,'edit') | strcmp(h.Style,'text')
    h.String = val;
else
    ind = find(ismember(h.String,string(val)));
    assert(~isempty(ind),...
        sprintf('Callback returned a value that is not in the set of options for the popup (%s).',h.Tag))
    h.Value = ind;
end
end

function mycallback(hObj,~)
user_callback = hObj.UserData.callback;
eventdata.previous_value = hObj.UserData.value;
prop_name=hObj.UserData.Tag;
if strcmp(hObj.Style,'edit')
    eventdata.new_value = hObj.String;
else
    eventdata.new_value = hObj.String{hObj.Value};
end
hObj.UserData.value = eventdata.new_value;

if abs(nargout(user_callback))>0  % See if user is giving output, chris made abs because varargout makes nargout negative
    correct_value = user_callback(hObj,eventdata);
    if strcmp(hObj.Style,'edit') | strcmp(hObj.Style,'text') 
        hObj.String = correct_value;
    else
        ind = find(ismember(hObj.String,string(correct_value)));
        assert(~isempty(ind),...
            sprintf('Callback returned a value that is not in the set of options for the popup (%s).',hObj.Tag))
        hObj.Value = ind;
    end
    hObj.UserData.value = correct_value; % Has to be after the assert statement in case of incorrect value
    %     updateGUI(hObj,prop_name,correct_value)
else
    user_callback(hObj,eventdata);
end

end
