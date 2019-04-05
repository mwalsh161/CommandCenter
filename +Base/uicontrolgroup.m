function [ h ] = uicontrolgroup(props, callback, varargin)
%uicontrolgroup UI tool to help create editable groups
%   editable elements can be a popup or textedit
%   Inputs:
%       props: list of structs. Must have following fields:
%           name - string of property name (used as tag for uicontrol
%               handle). Must be unique
%           display_name - name displayed in GUI (e.g. also specify units)
%               Can be empty strings as well, in which case name is used.
%           default - for text edits, just a  string/number. for popup, should be
%               an integer between 1 and length of options
%           options - for text edit should be empty. For popup should be
%               cell array of strings.
%           enable - 'on'/'off' (passed straight to uicontrol). Default: 'on'
%       callback(hObj,eventdata) - function handle for each uicontrol field
%           User should take advantage of hObj.UserData.getValue(hObj):
%               val = getValue(hObj)
%       varargin gets passed directly to panel that is created to house
%           everything (tip: specify parent here)
%           uicontrolgroup will use UserData as a line height specification
%           in units of characters.
%   Outputs:
%       h: handle to panel that is created to contain everything
%           h.UserData is a struct with following fields
%               'label_handles': list of handles to the static text
%               'input_handles': list of handles to the input field
%               'setValue': function handle: setValue(hPanel,name,val).
%                   Abstracts the uicontrol type
%
%   NOTE: the handle to the uicontrol (which is what your callback will
%   receive) has an hObj.UserData struct with fields defining function handles:
%       'setValue': setValue(hPanel,prop_name,val)
%       'getValue': val = getValue(hObj,current_prop_value)
%
%   NOTE: the position of the labels is determined by the longest one, and
%   the remainder of the space is for the uicontrol.  The width of the
%   parent will not be changed, but the length can be.
%
%   NOTE: ui elements are disabled if the wrong type is supplied. NaN is
%   NOT considered numeric in this, so setting a value to NaN is a way to
%   disable a ui input field that is intended to be numeric, until a number
%   is set (ex: when an instrument is disconnected, the module can set all 
%   values to NaN until reconnected). Could override this feature by
%   keeping things as strings and converting in set/get methods.
%
%   NOTE: If adding additional functionaltiy, you must change in 3 places
%       1) the main method 2) getValue 3) setValue


h = uipanel('visible','off',varargin{:});

d = version('-date');
d = datetime(d);
if d.Year < 2017
    posString = 'Position';
else
    posString = 'InnerPosition';
end

h.Units = 'characters';
width = h.(posString)(3);
border = 1;
spacing = 1.75;
if isnumeric(h.UserData) && length(h.UserData(:))==1
    spacing = h.UserData;
end
props = fliplr(props);  % Go from bottom up

label_widths = [];
row = 0;  % Not always equal to i, if we have to skip a prop
n = 1;    % Not always equal to row, because of uitable support
for i = 1:length(props)
    prop = props(i);
    if isempty(prop.name) || ~isempty(findall(h,'tag',prop.name))
        warning('UICONTROLGROUP:bad_name','%s ignored prop with no or duplicate name.',mfilename);
        continue;
    end
    if ~isfield(prop,'display_name') || isempty(prop.display_name)
        display = prop.name;
    else
        display = prop.display_name;
    end
    if ~isfield(prop,'enable') || isempty(prop.enable)
        enable = 'on';
    else
        enable = prop.enable;
    end
    tag = prop.name;
    % Setup basic properties that most will share
    h_text = uicontrol(h,'style','text',...
              'string',[display ':'],...
              'horizontalalignment','right',...
              'units','characters',...
              'position',[border border+spacing*row 30 1.25],...  % Only height matters right now
              'tag',[tag '_label']);
    label_widths(n) = h_text.Extent(3);
    ui = uicontrol(h,'units','characters',...
              'horizontalalignment','left',...
              'position',[border border+spacing*row 30 1.25],...  % Only height matters right now
              'tag',tag,...
              'callback',callback,...
              'enable',enable,...
              'UserData',struct('setValue',@setValue,'getValue',@getValue,'Style',[],'readonly',prop.readonly));
    % Branch off to specific styles
    if isfield(prop,'options') && ~isempty(prop.options)
        % Popup
        style = 'popup';
        ui.Style = style; 
        ui.String = prop.options; % This converts all options to strings
        if isempty(prop.default)
            ui.Value = 1;
            ui.Enable = 'off';
        else
            ui.Value = prop.default;
        end
        ui.UserData.options = prop.options;  % This maintains original type
    elseif (isnumeric(prop.default) && length(prop.default)<=1) || ischar(prop.default)
        style = 'edit';
        ui.Style = style;
        ui.String = prop.default;
        if isnumeric(prop.default)
            ui.UserData.numeric=true;
            if isnan(prop.default)  % Consider NaN as disabling input
                ui.Enable = 'off';
            elseif strcmp(ui.Enable,'off') && ~prop.readonly
                ui.Enable = 'on';
            end
        else
            ui.UserData.numeric=false;
        end
    elseif islogical(prop.default) && length(prop.default)==1
        style = 'checkbox';
        ui.Style = style;
        ui.Value = prop.default;
    elseif isnumeric(prop.default) && numel(prop.default)>1
        style = 'uitable';
        delete(ui)
        extra_rows = size(prop.default,1)-1;
        cols = size(prop.default,2);
        % Base of UI table should be at normal row, hegith extended
        ui = uitable(h,'units','characters',...
            'tag',tag,...
            'CellEditCallback',callback,...
            'enable',enable,...
            'UserData',struct('setValue',@setValue,'getValue',@getValue),...
            'RowName',[],'ColumnName',[],'ColumnEditable',true,...
            'columnformat',cellfun(@(a)'numeric',cell(1,cols),'UniformOutput',false),...
            'data',prop.default);
        ui.OuterPosition([2 4]) = [border+spacing*row 1.25+spacing*extra_rows]; 
        % Squeeze uitable vertically by moving bottom up (leave a few
        % pixels so scroll bars aren't made)
        ui.Units = 'pixels';
        extra_space = ui.Position(4) - ui.Extent(4);
        ui.Position(4) = ui.Extent(4)+5;
        ui.Position(2) = ui.Position(2)+extra_space;
        ui.Units = 'characters';
        % Add in additional rows
        row = row + extra_rows;
        % Move UI text up to top
        h_text.Position(2) = border+spacing*row;
    elseif contains('Base.Module',superclasses(prop.default))
        style = 'module';
        ui.Enable = 'on'; % Override this ui element, since in this context enable defines callbacks
        module_list = ui;
        ui = uipanel(h,'bordertype','none','units','characters','tag',tag);
        ui.UserData.readonly = prop.readonly;
        ui.UserData.selection = module_list;
        module_list.Parent = ui;
        ui.Position = module_list.Position;
        module_list.Units = 'normalized';
        module_list.Position = [0 0 0.7 1];
        module_list.Style = 'popup';
        module_list.UserData.Style = style; % Necessary for the getValue callback
        button2 = uicontrol(ui,'style','pushbutton','string','Settings','callback',@getSettings,...
                'units','normalized','HandleVisibility','off','UserData',module_list);
        button2.Position = [0.7 0 0.3 1];
        module_list.String = {};
        module_type = class(prop.default); % Case length = 0 and > 1
        if isempty(prop.default)
            button2.Enable = 'off';
        else
            for j = 1:length(prop.default)
                module_list.String{j} = class(prop.default(j));
            end
            if length(prop.default) == 1
                supers = superclasses(prop.default);
                ind = find(contains(supers,'Base.Module'))-1;
                assert(ind > 0,sprintf('Failed to find Modules.* superclass for %s',class(prop.default)));
                module_type = supers{ind}; % Case = 1
            end
            if ~prop.readonly
                module_list.String{end+1} = '_Remove';
            end
        end
        if ~prop.readonly
            module_list.String{end+1} = ['_Add ' module_type]; % Need to keep the class string for selectModules
        end
        ui.UserData.settings = button2;
    else % Not supported
        delete([h_text, ui]);
        warning('UICONTROLGROUP:not_supported','%s is currently not a supported type for %s. Ignored.',prop.name,mfilename)
        continue
    end
    % Because not everything is a uicontrol, we will use UserData to declare style
    ui.UserData.Style = style;
    
    ui_labels(n) = h_text;
    ui_handles(n) = ui;
    row = row + 1;
    n = n + 1;
end
% Fix horizontal position now that we know the extent for each item
label_widths = max(label_widths);
for i = 1:length(ui_labels)
    ui_labels(i).Position(3) = label_widths;
    ui_handles(i).Position(1) = label_widths+border;
    ui_handles(i).Position(3) = width-(label_widths+border*2);
    if strcmp(ui_handles(i).UserData.Style,'checkbox')
        ui_handles(i).Position(3)=3; % Just needs to cover the checkbox
    elseif strcmp(ui_handles(i).UserData.Style,'uitable')
        % Make columns fill the table space
        cols = size(ui_handles(i).Data,2);
        ui_handles(i).Units = 'pixels';  % ColumnWidth takes pixel values only
        col_width = ui_handles(i).(posString)(3)/cols-1;
        ui_handles(i).Units = 'characters';  % Change back for consistency
        ui_handles(i).ColumnWidth = cellfun(@(a)col_width,cell(1,cols),'UniformOutput',false);
    end
end
% Set top of panel to be top of first (last made) prop
h.Position(4) = sum(ui_handles(end).Position([2,4]))+border;
h.UserData = struct('label_handles',ui_labels,'input_handles',ui_handles,'setValue',@setValue);
h.BorderType='None';
h.Visible = 'on';
end

% Return a value without caller caring about uicontrol type
function [val,abort,reset] = getValue(hObj,current)
% hObj is the uicontrol handle
abort = false;
reset = false;
switch hObj.UserData.Style
    case 'edit'
        val = hObj.String;
        if hObj.UserData.numeric
            val = str2double(val);
            assert(~isnan(val),'Value must be numeric.')
        end
    case 'popup'
        val = hObj.UserData.options{hObj.Value};
    case 'checkbox'
        val = logical(hObj.Value);
    case 'uitable'
        val = hObj.Data;
    case 'module'
        option = strsplit(hObj.String{hObj.Value},' ');
        option = option{1};
        switch option
            case '_Add'
                [val,abort,reset] = selectModule(hObj.String{end});
                val = [current,val]; % Append instead of replace
            case '_Remove' % Does not delete (so duplicates wont be destroyed)
                if length(current) == 1 % Reset will remove all
                    val = '';
                    reset = true;
                else % Prompt to see which one
                    opts = arrayfun(@class,current,'uniformoutput',false);
                    opts{end+1} = '__all__';
                    f = figure('name','Select Module to Remove','IntegerHandle','off','menu','none',...
                        'toolbar','none','visible','off','units','characters');
                    f.Position(3) = 50;
                    lbox = listbox(f,'OK','string',opts);
                    if ~isvalid(f) % User aborted
                        return
                    end
                    ind = lbox.Value;
                    delete(f);
                    choice = opts{ind};
                    if strcmp(choice,'__all__')
                        reset = true;
                        val = '';
                    else
                        mask = true(size(current));
                        mask(ind) = false;
                        val = current(mask);
                    end
                end
            otherwise
                val = '';
                abort = true; % Silent fail
        end
    otherwise
        error('Unsupported uicontrol type!')
end
end

% Method to streamline updating the GUI. Necessary to abstract away the
% different uicontrol elements and the different behavior among them.
function setValue(hPanel,name,val)
% hPanel: handle to panel
% name: name of property (tag)
% val: value to set
hObj = findobj(hPanel.UserData.input_handles,'tag',name,'-depth',0); % Don't search recursively
assert(~isempty(hObj),sprintf('Could not find property %s in %s',name,mfilename))
switch hObj.UserData.Style
    case {'edit','text'}
        if hObj.UserData.numeric
            if ~isnumeric(val)
                val = str2num(val); %#ok<ST2NM>; str2num performs eval; meaning str2num('pi') works
                if isempty(val) % To keep same performance of str2double
                    val = NaN;
                end
            end
            if isnan(val)
                hObj.Enable = 'off';
            elseif strcmp(hObj.Enable,'off') && ~hObj.UserData.readonly
                hObj.Enable = 'on';
            end
        end
        hObj.String = val;
    case 'popup'
        ind = find(ismember(hObj.String,num2str(val)),1);
        if isempty(ind)
            if ~isnan(val)
                warning('UICONTROLGROUP:set_value','Callback returned a value that is not in the set of options for the popup (%s).',hObj.Tag)
            end
            hObj.Enable='off';
        else
            if strcmp(hObj.Enable,'off') && ~hObj.UserData.readonly
                hObj.Enable='on';
            end
            hObj.Value = ind;
        end
    case 'checkbox'
        if length(val)==1 && (islogical(val) || val==0 || val==1)
            if strcmp(hObj.Enable,'off') && ~hObj.UserData.readonly
                hObj.Enable='on';
            end
            hObj.Value = logical(val);
        else
            hObj.Enable = 'off';
            warning('UICONTROLGROUP:set_value','Invalid logical for property "%s".',name);
        end
    case 'uitable'
        hObj.Data = val;
    case 'module'
        if ~hObj.UserData.readonly
            add_str = hObj.UserData.selection.String{end}; % Keep last "add" string
        end
        hObj.UserData.selection.String = {}; % Reset
        if isempty(val)
            hObj.UserData.settings.Enable = 'off';
        else
            for i = 1:length(val)
                hObj.UserData.selection.String{i} = class(val(i));
            end
            hObj.UserData.settings.Enable = 'on';
            if ~hObj.UserData.readonly
                hObj.UserData.selection.String{end+1} = '_Remove';
            end
        end
        if ~hObj.UserData.readonly
            hObj.UserData.selection.String{end+1} = add_str;
        end
        % Make sure value is always on legit option or 1 if has to
        hObj.UserData.selection.Value = max(min(hObj.UserData.selection.Value,length(val)),1);
    otherwise
        error('Unsupported uicontrol type!')
end
end

function [module,abort,reset] = selectModule(module_type)
reset = false;
abort = false;
% Remove "Empty: " if there
module_type = strsplit(module_type,'.'); % "%s Modules.*"; need "*" part
module_type = Modules.(module_type{end}).modules_package;
f = figure('name','Select Module','IntegerHandle','off','menu','none',...
    'toolbar','none','visible','off','units','characters','resize','off');
f.Position(3:4) = [50,0];
parent_menu = uimenu(f,'Text',module_type);
package = ['+' module_type];
Base.Manager.getAvailModules(package,parent_menu,@selected,@(~)false);
f.Visible = 'on';
uiwait(f); % Let user select
if ~isvalid(f) % User aborted/closed
    abort = true;
    module = '';
    return
end
module = f.UserData;
delete(f);
module = eval(sprintf('%s.instance',module));
end
function getSettings(hObj,~)
% Grab instance and call settings
ind = hObj.UserData.Value;
objString = hObj.UserData.String{ind};
assert(~isempty(objString),'Cannot have empty module string')
assert(objString(1)~='_','Cannot get settings for Add/Remove buttons');
if length(strsplit(objString,' ')) == 1 % Means, "Empty: " is not there
    obj = eval(sprintf('%s.instance',objString));
    f = figure('name',sprintf('%s Settings (close when done)',objString),'IntegerHandle','off','menu','none',...
        'toolbar','none','visible','off','units','characters','resize','off','windowstyle','modal');
    f.Position(3) = 100;
    panel = uipanel(f);
    obj.settings(panel);
    child = allchild(panel);
    h = 0; % Get height
    for i = 1:length(child)
        new_h = sum(child(i).Position([2,4]));
        if new_h > h
            h = new_h;
        end
    end
    f.Position(4) = h;
    f.Visible = 'on';
end
end
function selected(hObj,~)
    [~,fig] = gcbo;
    fig.UserData = hObj.UserData;
    uiresume(fig);
end