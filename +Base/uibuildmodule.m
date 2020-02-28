function [code,f] = uibuildmodule(varargin)
%UIBUILDMODULE An interactive tool to help bulid a module and access a function
%   Sometimes it can be difficult to understand how to grab the instance to
%   a particular module. This tool will walk you through the steps
%   interactively and return the code that is generated along the way. You
%   can also request to have the code be assigned in the main workspace.
% Input: Parenths indicate optional positional arguments. Brackets are
%   optional name/value pairs.
%   [varname]: ('my_mod') The name of the variable for the module to be
%       assigned.
%   [uiwait]: (false). If true, uiwait will be called to prevent code
%       execution and the result will be returned. If false, code execution
%       will continue and an empty string will be returned.
% Output:
%   code: A char array of the lines of code generated.
%   f: figure handle. If uiwait is true, this will be a deleted figure.

p = inputParser();
addParameter(p,'varname','my_mod',@isvarname);
addParameter(p,'uiwait',false,@islogical);
parse(p,varargin{:});
p = p.Results;

% Cache module_types
persistent module_types
if isempty(module_types)
    [~,module_types,~] = Base.GetClasses('+Modules');
end
baseUI = {'FontName','fixedwidth',...
                    'FontSize',10,...
                    'horizontalalignment','left',...
                    'units','characters'};

newstuff = false;
f = figure('name','Build Module Code','IntegerHandle','off','menu','none',...
                'toolbar','none','CloseRequestFcn',@done,'units','characters');
help_text = {'The code will appear here as it gets generated.',...
             'To start, select the module type from a menu.',...
             '  You can send the code places from the File menu',...
             '  When finished, simply close this window.', ...
             '',''};
nHelp = length(help_text);
code =     {['>> ' p.varname ' = $1.instance($2);']};
codeH = uicontrol(f,'style','text','String',[help_text code],...
    'units','normalized','position',[0,0,1,1],'FontName','fixedwidth',...
    'FontSize',10,'horizontalalignment','left');

% Build menus
parent_menu = uimenu(f,'Label','File');
uimenu(parent_menu,'label','Copy to clipboard','callback',{@send,'copy'});
uimenu(parent_menu,'label','Send to main workspace','callback',{@send,'base'});

n = length(module_types);
mod_menu = gobjects(1,n);
for i = 1:n
    package = ['+' Modules.(module_types{i}).modules_package];
    mod_name = strsplit(module_types{i},'.'); mod_name = mod_name{end};
    mod_menu(i) = uimenu(f,'Label',mod_name);
    Base.Manager.getAvailModules(package,mod_menu(i),@selected,@(~)false);
end

if p.uiwait
    code = get_code();
    uiwait(f);
else
    code = '';
end
    
    function line_of_code(ht)
        h = uicontrol(f,baseUI{:},'style','text','String','>> ');
        h(1).Position([1,2]) = [0,ht];
        h(1).Position(3) = h(1).Extent(3);
        
        h(2) = uicontrol(f,baseUI{:},'style','edit');
        h(2).Position([1,2]) = [sum(h(1).Position([1,3])),ht];
        h(2).Position(3) = 10;
        
        h(3) = uicontrol(f,baseUI{:},'style','text','String',' = ');
        h(3).Position([1,2]) = [sum(h(2).Position([1,3])),ht];
        h(3).Position(3) = h(3).Extent(3);
        
        h(4) = uicontrol(f,baseUI{:},'style','popup','String',[{'Select'} module_types]);
        h(4).Position([1,2]) = [sum(h(3).Position([1,3])),ht];
        h(4).Position(3) = 30;
    end

    function done(hObj,~)
        if newstuff && ~p.uiwait
            resp = questdlg('You have unsaved work, are you sure you want to leave?',...
                mfilename,'Copy and Quit','Quit','Cancel','Copy and Quit');
            if strcmp(resp,'Copy and Quit')
                send([],[],'copy');
            elseif strcmp(resp,'Cancel')
                return
            end
        end
        delete(hObj);
    end
    function send(~,~,opt)
        code = get_code();
        newstuff = false;
        switch opt
            case 'copy'
                clipboard('copy',code);
            case 'base' % Send to base workspace
                ise = evalin( 'base', sprintf('exist(''%s'',''var'') == 1',p.varname));
                if ise
                    resp = questdlg(sprintf('"%s" already exists in base workspace.',p.varname),...
                        mfilename,'Overwrite','Cancel','Cancel');
                    if strcmp(resp,'Cancel')
                        return
                    end
                end
                evalin('base',code);
            otherwise
                error('"%s" unsupported',opt)
        end
        
    end
    function code = get_code()
        code = strip(strrep(strjoin(codeH.String(nHelp+1:end),'\n'),'>>',''));
    end
    function update_UI_code(ID,code)
        for j = 1:length(codeH.String)
            if contains(codeH.String{j},ID)
                codeH.String{j} = strrep(codeH.String{j},ID,code);
                drawnow;
                return
            end
        end
    end

    function selected(hObj,~) % This updates UI
        newstuff = true;
        module_name = hObj.UserData;
        update_UI_code('$1',module_name);
        % Get module/function name and inputs
        module_inputs = {};
        method_inputs = {};
        % Modules might need module input too
        mc = meta.class.fromName(module_name);
        ind = cellfun(@(a)strcmp(a,'instance'),{mc.MethodList.Name});
        m_instance = mc.MethodList(ind);
        inputID = '';
        nInput = length(m_instance.InputNames);
        for j = 1:nInput
            if j == nInput
                inputID = [inputID m_instance.InputNames{j},'=...'];
            else
                inputID = [inputID m_instance.InputNames{j},'=..., '];
            end
        end
        update_UI_code('$2',inputID);
        if ~isempty(m_instance.InputNames) % Only if input
            module_inputs = inputdlg(m_instance.InputNames,'Module instance arguments (MATLAB expression!!)',[1 75]);
            if isempty(module_inputs) % User aborted, no worries
                return
            end
        end
        update_UI_code(inputID, strjoin(module_inputs, ', '));
        return
        % Now get method name
        f = figure('name','Select Method','IntegerHandle','off','menu','none',...
            'toolbar','none','visible','off','units','characters');
        f.Position(3) = 50;
        ind = cellfun(@(a)~iscell(a)&&strcmp(a,'public'),{mc.MethodList.Access}); % Cell if specific access granted (i.e. not public)
        avail_methods = mc.MethodList(ind);
        lbox = listbox(f,'OK','string',{avail_methods.Name});
        if ~isvalid(f) % User aborted, no worries
            return
        end
        m_method = avail_methods(lbox.Value);
        delete(f);
        method_name = m_method.Name;
        
        % Get method inputs
        inp_names = m_method.InputNames;
        if ~m_method.Static
            inp_names = m_method.InputNames(2:end); % Ignore obj
        end
        method_inputs = inputdlg(inp_names,sprintf('Module %s arguments (MATLAB expression!!)',method_name),[1 75]);
        if isempty(method_inputs) % User aborted, no worries
            return
        end
        % Convert to strings and numbers as necessary
        method_inputs = cellfun(@eval,method_inputs,'UniformOutput',false);
    end
    end