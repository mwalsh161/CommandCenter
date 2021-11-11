function [code,f] = uibuild(block,varargin)
% Module.uibuild creates a UI to help you build a module instance and
% optionally look through its methods
% INPUTS:
%   (block): default false. Calls uiblock until window is closed. At that
%       point, the code generated is returned as a char vector.
%   All additional inputs are piped to the figure as name/value pairs.
% OUTPUTS:
%   code: if block=true, this will return all the code generated.
%       Otherwise, it will be an empty char vector.
%   f: figure handle. This will be deleted if block=true.

persistent root % Cache once calculated
if isempty(root)
    root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % Root AutomationSetup/
    root = fullfile(root,'Modules');
end

if nargin < 1
    block = false;
end

[f] = UseFigure('Base.Module.uibuild','numbertitle','off','name','Build Module Code',...
    'toolbar','none','menubar','none','units','char','handlevisibility','off',true);
if ~isempty(varargin)
    set(f,varargin{:});
end
% globals to be used once module has been built (for method creation)
code = '';
MODULE = '';
MODULEVAR = '';
METHODVAR = '';
METHODNAME = '';
MODULEMC = []; % metaclass
ht = 4;
line_ht = 2;

% Setup action buttons for copying/sending. Enable once "code" ready in `done`
hAction = ui(ht + 2*line_ht,'pushbutton','Copy',@(~,~)copyCode(),f);
hAction.Position([1 4]) = [5 line_ht];
hAction.Position(3) = hAction.Position(3) + 5;

hAction(2) = ui(hAction(1),'pushbutton','Eval',@(~,~)evalCode());
hAction(2).Position([1 3]) = hAction(2).Position([1 3]) + 5;
hAction(2).Position(4) = line_ht;

hAction(3) = ui(hAction(2),'pushbutton','Put in Active Editor',@(~,~)putCode());
hAction(3).Position([1 3]) = hAction(3).Position([1 3]) + 5;
hAction(3).Position(4) = line_ht;
set(hAction,'enable','off')

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

f.Position(4) = sum(packageH(1).Position([2,4])) + line_ht*3;
uicontrol(varnameH);

if block
    uiwait(f);
end

% Nested Helper functions:
    %% This block is for module construction
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
        delete(packageH(n).UserData.dependent);
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
            MODULEMC = meta.class.fromName(module_name);
            
            % Check to see if inputs necessary (check instance method and constructor)
            class_name = module_name(find(module_name=='.',1,'last')+1:end);
            precedence = {'instance',class_name};
            InputNames = {}; % Fall back is default constructor (e.g. no inputs)
            for i = 1:length(precedence)
                mf = MODULEMC.MethodList(ismember({MODULEMC.MethodList.Name},precedence{i}));
                if isempty(mf); continue; end
                InputNames = mf.InputNames; break;
            end            
            h = makeInputs(target,InputNames,@done);
            target.UserData.dependent = h; % Make sure they will get cleaned up
        end
    end
    function done(h,~)
        % Make sure varname is all good
        MODULEVAR = varnameH.String;
        if ~isvarname(MODULEVAR)
            errordlg(sprintf('"%s" is not a valid MATLAB variable name.',MODULEVAR),'Fix variable name!')
            return
        end
        % Convert inputs to strings
        input_strs = cell(1,length(h.UserData.inputs));
        for i = 1:length(h.UserData.inputs)
            input_strs{i} = h.UserData.inputs(i).String;
        end
        % Walk back through and build code
        n = length(packageH);
        MODULE = cell(1,n);
        for i = 1:n
            MODULE{i} = packageH(i).String{packageH(i).Value};
        end
        MODULE = strrep(strjoin(MODULE,'.'),'+','');
        code = [MODULEVAR ' = ' MODULE '.instance(' strjoin(input_strs,', ') ');'];
        set(hAction,'enable','on');
        
        % Clean up everything but the carrot (static(1))
        for i = 1:length(packageH)
            delete(packageH(i).UserData.dependent);
            delete(packageH(i));
        end
        delete([varnameH, static(2)]); % equals sign
        
        h = ui(static(1),'text',code,[]);
        addMethod(h);
    end
    %% Previous callbacks no longer relevant once we get here
    function addMethod(h,~) % Make new line and use methodNext callbacks
        ht = h.Position(2) - line_ht;
        static(1) = ui(ht,'text','>> ',[],f);
        varnameH = ui(static(1),'edit','dat_out',@verify_varname);
        static(2) = ui(varnameH,'text',[' = ' MODULEVAR '.'],[]);
        % only show public and non hidden
        methods = MODULEMC.MethodList;
        mask = ~[methods.Hidden] & ~[methods.Static] &...
            arrayfun(@(a)isequal(a.Access,'public'),methods');
        methods = methods(mask);
        % Organize by defining class
        opts = [{MODULE}; superclasses(MODULE)]; % use this order
        defining = [methods.DefiningClass];
        finalList = {};
        for i = 1:length(opts)
            if i > 1 % Prepend defining class name
                finalList = [finalList; ...
                    arrayfun(@(a)[opts{i} '.' a.Name],methods(ismember({defining.Name},opts{i})),'UniformOutput',false)];
            else
                finalList = {methods(ismember({defining.Name},opts{i})).Name}';
            end
        end
        if length(finalList)~=length(methods); warning('Missed some methods!'); end
        fn = ui(static(2),'popup', finalList,@methodNext,'UserData',struct('dependent',gobjects(0)));
        % Extend figure
        f.Position(4) = f.Position(4) + fn.Position(4);
    end
    function methodNext(target,~)
        val = target.String{target.Value};
        % Make width tight for selection
        temp = ui(target,'edit',val,[],'visible','off');
        target.Position(3) = temp.Extent(3)+5;
        delete(temp);
        if target.Value==1; return; end % Empty choice; nothing else to do
        
        % method names are described in the dropdown with their defining
        % class (separated by "."). We don't need that for the actual code.
        val = split(val,'.');
        METHODNAME = val{end};
        
        % Clean up dependent
        delete(target.UserData.dependent);
        
        % Get input names
        methodMC = MODULEMC.MethodList(ismember({MODULEMC.MethodList.Name},METHODNAME));
        InputNames = methodMC.InputNames(...
            ~cellfun(@(a)isempty(a)||strcmp(a,'~'),methodMC.InputNames)...
            );
        if ~methodMC.Static % Remove obj
            InputNames = InputNames(2:end);
        end
        
        h = makeInputs(target,InputNames,@methodDone);
        % The last thing on h is the check box "finished" option
        h(end).UserData.dependent = [h target]; % Make sure they will get cleaned up `methodDone`
        target.UserData.dependent = h; % Make sure they will get cleaned up in `methodNext`
    end
    function methodDone(h,~)
        % Make sure varname is all good
        METHODVAR = varnameH.String;
        if ~isvarname(METHODVAR)
            errordlg(sprintf('"%s" is not a valid MATLAB variable name.',METHODVAR),'Fix variable name!')
            return
        end
        % Convert inputs to strings
        input_strs = cell(1,length(h.UserData.inputs));
        for i = 1:length(h.UserData.inputs)
            input_strs{i} = h.UserData(i).inputs.String;
        end
        % build code
        codeln = [METHODVAR ' = ' MODULEVAR '.' METHODNAME '(' strjoin(input_strs,', ') ');'];
        code = [code newline codeln];
        
        % Clean up everything but the carrot (static(1))
        
        delete([h.UserData.dependent, ...
                h.UserData.inputs, ...
                varnameH, ...
                static(2)]); % equals sign and module variable name
        
        ui(static(1),'text',codeln,[]);
    end
    %% Actions
    function copyCode()
        if isempty(code); return; end
        clipboard('copy',code);
    end
    function evalCode()
        if isempty(code); return; end
        protected = {MODULEVAR, METHODVAR};
        for i = 1:length(protected)
            if ~isempty(protected{i}) && evalin('base',sprintf('exist(''%s'',''var'')',protected{i}))
                resp = questdlg(sprintf('"%s" exists in base workspace. Overwrite it?',protected{i}),...
                    'Module.uibuild','Overwrite','Cancel','Overwrite');
                if strcmp(resp,'Cancel'); return; end
            end
        end
        try
            evalin('base',code);
        catch err
            errordlg(err.message,err.identifier)
        end
    end
    function putCode()
        if isempty(code); return; end
        editor = matlab.desktop.editor.getActive;
        cursor = editor.Selection; % line, col at end of selection
        if ~isequal(cursor(1:2),cursor(3:4))
            warning('MODULE:UIBUILD:selected_text','Ignoring active selection (highlighted text), and placing code after selection.');
        end
        % Note this won't delete any selected text first
        editor.insertTextAtPositionInLine(code,cursor(3),cursor(4));
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

function h = makeInputs(target,InputNames,doneCallback)
% Build UI components; the UserData for the done button is the input UIs
inputs = gobjects(size(InputNames));
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

h(end+1) = ui(h(end),'pushbutton','<HTML>&#10004;</HTML>',doneCallback,...
    'foregroundcolor',[0 0.7 0],'UserData',struct('inputs',inputs));
h(end).Position(3) = 5;

% Make first input active
if ~isempty(inputs)
    uicontrol(inputs(1));
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