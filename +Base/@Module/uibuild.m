function code = uibuild()
% Biggest limitation now is no horizontal scrollbar

persistent root % Cache once calculated
if isempty(root)
    root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % Root AutomationSetup/
    root = fullfile(root,'Modules');
end

f = UseFigure('Base.Module.uibuild','numbertitle','off','name','Build Module',...
    'toolbar','none','menubar','none','units','char','handlevisibility','off',true);
ht = 1;

static(1) = ui(ht,'text','>> ',[],f);
varnameH = ui(static(1),'edit','my_mod',@verify_varname);
static(2) = ui(varnameH,'text',' = ',[]);

[~,~,packages] = Base.GetClasses(root);
for j = 1:length(packages)
    packages{j} = ['+' packages{j}];
end
% For packageH ui elements, UserData is a struct with fields:
%   ind: their index into packageH
%   dependent: any other relevant UI created to dependent on state of self
packageH(1) = ui(static(2),'popup',packages,@next,...
    'UserData',struct('ind',1,'dependent',gobjects(0)));

f.Position(4) = packageH(1).Position(4) + 2;
uicontrol(varnameH);

% Nested Helper functions:
%   next: callback for all packagesH; renders next step in UI
%   done: callback for check button; renders final copy and returns
    function next(target,~)
        val = target.String{target.Value};
        % Make width tight for selection
        temp = ui(target,'edit',val,[],'visible','off');
        target.Position(3) = temp.Extent(3)+5;
        delete(temp);
        if target.Value==1; return; end % Empty choice; nothing else to do
        
        % Build up relative path
        n = target.UserData.ind;
        relpath = cell(1,n);
        for i = 1:n
            relpath{i} = packageH(i).String{packageH(i).Value};
        end
        relpath = fullfile(relpath{:});
        
        % Clean up stale UI
        for i = n+1:length(packageH)
            delete(packageH(i).UserData.dependent);
            delete(packageH(i));
        end
        packageH(n+1:end) = [];
        
        if val(1)=='+' % then non-leaf node
            [~,module_strs,sub_packages] = Base.GetClasses(root,relpath);
            for i = 1:length(sub_packages)
                sub_packages{i} = ['+' sub_packages{i}];
            end
            % Alphabetic order
            sub_packages = sort(sub_packages);
            module_strs = sort(module_strs)';
            items = [sub_packages; module_strs];
            
            % Make next popup
            packageH(end+1) = ui(target,'popup',items,@next,...
                'UserData',struct('ind',n+1,'dependent',gobjects(0)));
        else % leaf-node (e.g. full module name)
            verify_varname(varnameH,[])
            % Get module name (**specific to this application**)
            relpath(relpath == '+') = []; % Remove +
            module_name = strrep(relpath,filesep,'.');
            mc = meta.class.fromName(module_name);
            
            % Check to see if inputs necessary (check instance method and constructor)
            class_name = module_name(find(module_name=='.',1,'last')+1:end);
            precedence = {'instance',class_name};
            InputNames = {}; % Fall back is default constructor (e.g. no inputs)
            for i = 1:length(precedence)
                mf = mc.MethodList(ismember({mc.MethodList.Name},precedence{i}));
                if isempty(mf); continue; end
                InputNames = mf.InputNames; break;
            end
            inputs = gobjects(1,length(InputNames)); % Allocate memory for UI
            
            % Render UI inputs
            h = ui(target,'text','(',[]);
            if ~isempty(InputNames)
                for i = 1:length(InputNames)
                    h(end+1) = ui(h(end),'edit',InputNames{i},[],'tooltipstring',InputNames{i});
                    inputs(i) = h(end);
                    h(end+1) = ui(h(end),'text',', ',[]);
                end
                delete(h(end)); h(end) = []; % extra comma
            end
            h(end+1) = ui(h(end),'text',')',[]);
            
            h(end+1) = ui(h(end),'pushbutton','<HTML>&#10004;</HTML>',@done,...
                'foregroundcolor',[0 0.7 0],'UserData',inputs);
            h(end).Position(3) = 5;
            h(end+1) = ui(h(end),'pushbutton','<HTML>&#10008;</HTML>',@remove,...
                'foregroundcolor',[0.7 0 0]);
            h(end).Position(3) = 5;
            
            % Make first input active
            if ~isempty(inputs)
                uicontrol(inputs(1));
            end
            target.UserData.dependent = h; % Make sure they will get cleaned up
        end
    end

    function done(h,~)
        % Make sure varname is all good
        varnameStr = varnameH.String;
        if ~isvarname(varnameStr)
            errordlg(sprintf('"%s" is not a valid MATLAB variable name.',varnameStr),'Fix variable name!')
            return
        end
        % Convert inputs to strings
        input_strs = cell(1,length(h.UserData));
        for i = 1:length(h.UserData)
            input_strs{i} = h.UserData(i).String;
        end
        % Walk back through and build code
        n = length(packageH);
        module_str = cell(1,n);
        for i = 1:n
            module_str{i} = packageH(i).String{packageH(i).Value};
        end
        module_str = strrep(strjoin(module_str,'.'),'+','');
        code = [varnameStr ' = ' module_str '.instance(' strjoin(input_strs,', ') ')'];
        
        % Clean up everything but the carrot (static(1))
        for i = 1:length(packageH)
            delete(packageH(i).UserData.dependent);
            delete(packageH(i));
        end
        delete(varnameH);
        delete(static(2)); % equals sign
        
        h = ui(static(1),'text',code,[]);
        ui(h,'pushbutton','Add method call',@addMethod);
    end
    function remove(h,~)
        errordlg('Not implemented yet',':(');
    end
    function addMethod(h,~)
        errordlg('Not implemented yet',':(');
    end
end

%% Callbacks/helpers without shared state
function verify_varname(hObj,~)
if isvarname(hObj.String)
    hObj.BackgroundColor = [1 1 1];
    hObj.ForegroundColor = [0 0 0];
else
    hObj.BackgroundColor = [1 0 0];
    hObj.ForegroundColor = [1 1 1];
end
end

function uiH = ui(firstarg,style,string,callback,varargin)
% Wrapper to keep consistent styling and positioning
% firstarg: either a height or a uicontrol object
% IF height, the LAST varargin should be the parent
% All *other* varargin passed to uicontrol
% fixed_width if isfinite will be set regardless of style.
if isnumeric(firstarg)
    ht = firstarg;
    left = 0;
    pH = varargin{end};
    varargin(end) = [];
    assert(isgraphics(pH),'When first arg is height (numeric), last arg needs to be parent object.');
elseif isgraphics(firstarg)
    ht = firstarg.Position(2);
    if strcmpi(firstarg.Style,'text'); ht = ht + 0.3; end
    left = sum(firstarg.Position([1,3]));
    pH = firstarg.Parent;
end
if strcmpi(style,'popup')
    string = [{'------'}; string]; % '------' represents empty
end
uiH = uicontrol(pH,'FontName','fixedwidth','FontSize',10,...
    'horizontalalignment','left','units','characters',...
    'style',style,'string',string,'callback',callback,...
    'BusyAction','cancel',varargin{:});
% Fine tune width
switch lower(style)
    case 'text'
        ht = ht - 0.3; % Offset to make text aligned with edit fields
        uiH.Position(3) = uiH.Extent(3);
    case 'pushbutton'
        temp = ui(0,'text',string,[],'visible','off',pH);
        uiH.Position(3) = temp.Extent(3);
        delete(temp);
    case 'popup'
        temp = ui(0,'text',string{1},[],'visible','off',pH);
        uiH.Position(3) = temp.Extent(3)+5;
        delete(temp);
    case 'edit'
        temp = ui(0,'text',string,[],'visible','off',pH);
        uiH.Position(3) = temp.Extent(3);
        delete(temp);
end
uiH.Position([1,2]) = [left, ht];
end