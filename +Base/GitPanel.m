classdef GitPanel
    % GITPANEL parses and colorfully displays info from git (git status, git branch, ...). Most
    % importantly, it displays things in red or orange (being behind or having untracked changes;
    % uncommitted modified files) to encourage users to fix these things. This is useful to avoid copies
    % of CommandCenter which are year(s) behind. It also includes a menu (right click) which reminds the
    % user of useful git sequences, and the tooltip displays raw output from git status.
    
    properties
        panel;      % uipanel that is the parent.
        control;    % uicontrol that displays the current branch info. % For some reason, this property is empty from inside the object, but not from outside. Using panel.Children to access this uicontrol.
        menu;       % uicontextmenu to show useful git options.
    end
    
    properties
        enableLeftClick = false;
    end
    
    methods
        function obj = GitPanel(varargin)       % Expects GitPanel(figure, panel), but autogenerates these if nothing is given.
            if numel(varargin) == 2
                assert(isprop(varargin{1}, 'Type') && strcmp(varargin{1}.Type, 'uipanel'), 'Base.GitPanel(panel, figure) expects a uipanel.')
                assert(isprop(varargin{2}, 'Type') && strcmp(varargin{2}.Type, 'figure'), 'Base.GitPanel(panel, figure) expects a figure.')
                obj.panel = varargin{1};
                delete(obj.panel.Children);
                f = varargin{2};
            else    % Ignore arguments otherwise
                f = figure;
                f.Position(3:4) = f.Position(3:4)/2;
            
                obj.panel = uipanel(f);
            end
            
            obj.panel.Title = 'git branch';
            obj.panel.Units = 'characters';
            if ismac
                obj.panel.Position(4) = 2;
            else
                obj.panel.Position(4) = 2.4;
            end
            
            filedetails = ' &lt;file(s)&gt; <font color="gray">(--all)</font>';
            commitdetails = ' --author "&lt;you&gt;" --message "&lt;description&gt;"';
            
            obj.menu = uicontextmenu(f);
            uimenu(obj.menu, 'Label',  '<html><font color="purple">git</font> fetch', 'Callback', @(s,e)obj.update)
            uimenu(obj.menu, 'Label',  '<html>Copy hash', 'Separator', 'on', 'Callback', @(s,e)obj.copy)
            uimenu(obj.menu, 'Label',  '<html><b>Git Syntax Cheat Sheet:', 'Separator', 'on', 'Enable', 'off')
            uimenu(obj.menu, 'Label',  '<html> + Push a commit:', 'Enable', 'off')
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>'...
                                             '<font color="purple">git</font> ad&d' filedetails '<br>'...
                                             '<font color="purple">git</font> commit' commitdetails '<br>'...
                                             '<font color="purple">git</font> push origin &lt;current_branch&gt;'], 'Callback', @(s,e)(disp('Add files to a commit, then commit, and push to save changes. Check status first.')));
            uimenu(obj.menu, 'Label',  '<html> + Pull from origin:', 'Enable', 'off')
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>',...
                                             '<font color="purple">git</font> pull origi&n &lt;current_branch&gt;'], 'Callback', @(s,e)(disp('Pull to stay up to date. Check status first.')))
            uimenu(obj.menu, 'Label',  '<html> + Checkout a different branch:', 'Enable', 'off')
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>',...
                                             '<font color="purple">git</font> checkou&t &lt;existing_branch&gt;<br>'], 'Callback', @(s,e)(disp('Checkout to go to a different branch. Check status first.')))
            uimenu(obj.menu, 'Label',  '<html> + Make a new branch:', 'Enable', 'off')
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>',...
                                             '<font color="purple">git</font> branc&h &lt;new_branch&gt;<br>',...
                                             '<font color="purple">git</font> branch --set-upstream-to=origin/dev &lt;new_branch&gt;<br>',...
                                             '<font color="purple">git</font> checkout &lt;new_branch&gt;<br>'], 'Callback', @(s,e)(disp('Make a new branch. Check status first.')))
            
            obj.panel.UIContextMenu = obj.menu; 
            
            obj.control = uicontrol('Parent', obj.panel, 'Style', 'radiobutton', 'UIContextMenu', obj.menu, 'Units', 'characters', 'String', '', 'Tag', 'gitpanelcontrol');     % Text does not display HTML :(
            if ismac
                obj.control.Position(1:2) = [-2.75 0];
                obj.control.Position(3) = 200;
            else
                obj.control.Position(1:2) = [-3 0];
                obj.control.Position(3) = 200;
            end
            
            obj.panel.ButtonDownFcn = @obj.updateFromLeftClick;
            obj.control.Callback    = @obj.updateFromLeftClick;
                
            obj.update();
        end
        function updateFromLeftClick(obj, ~, ~)
            if obj.enableLeftClick
                obj.update();
            end
        end
        function update(obj)                    % git fetch
            obj.panel.Children.Enable = 'off';
            obj.panel.HighlightColor = [.5 0 .5];   % Purple
            obj.panel.Title = 'git fetch';
            drawnow;
            
            try
                gitSafe('fetch -q --all');
                
                [obj.panel.Children.String, obj.menu.UserData] = obj.info();
                obj.panel.Children.TooltipString = obj.tooltip();
                
                obj.panel.Children.Enable = 'on';
                obj.panel.HighlightColor = 'w';
                obj.panel.Title = 'git branch';
                drawnow;
            catch err
                obj.panel.Children.Enable = 'on';
                obj.menu.UserData = 'Could not find hash.';
                obj.panel.Children.String = '<html>Could not <font color="purple">git</font> fetch.';
                obj.panel.Children.TooltipString = 'Something terrible happened.'; %#ok<MCHV2>
                drawnow;
                
                rethrow(err);
            end
        end
        function thisbranch = thisbranch(~)     % Gets the branch that is currently checked out from the list of many provided by git branch.
            thisbranch = split(gitSafe('branch -v'), '* ');
            thisbranch = split(thisbranch{end}, newline);
            thisbranch = thisbranch{1};
        end
        function copy(obj, ~, ~)
            clipboard('copy', obj.menu.UserData);
            disp(['Hash ' obj.menu.UserData ' copied to clipboard.']);
        end
        function [str, hash] = info(obj)                % Fills the uicontrol
            thisbranch = makeHTML(obj.thisbranch());
            
            words_ = split(thisbranch, ' ');
            words = {};
            
            jj = 1;
            for ii = 1:length(words_)
                if ~isempty(words_{ii})
                    words{jj} = words_{ii}; %#ok<AGROW>
                    jj = jj + 1;
                end
            end
            
            message_ = split(thisbranch, words{2});
            messageraw = strtrim(message_{end});
            
            brackets = split(messageraw, {'[', ']'});
            
            while ~isempty(brackets) && isempty(brackets{1})
                brackets(1) = [];
            end
            
            message = '';
            
            name = words{1};
            hash = words{2};
            
            third = words{3};   % We're now going to check if our third word in the branch description begins with [, in which case, we are ahead or behind.
            
            test = '';
            if numel(third) >= 6
                test = third(1:6);
            end

            switch test
                case '[ahead'
                    commas = split(brackets{1}, {', '});
                    
                    if numel(commas) == 2
                        message = ['&nbsp;&nbsp;<font color="orange">[' commas{1} ',</font> <font color="red">' commas{2} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                    
                    else
                        message = ['&nbsp;&nbsp;<font color="orange">[' brackets{1} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                    end
                case '[behin'
                    message = ['&nbsp;&nbsp;<font color="red">[' brackets{1} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                otherwise
            end
            
            status = gitSafe('status');
            
            notinstalled = contains(status, 'git is not installed');
            modified = contains(status,'Changes not staged for commit:') || contains(status,'Changes to be committed:');
            untracked = contains(status,'Untracked files:');
            
            if notinstalled
                str = '<html>git is not installed';
                return;
            end
            
            if modified && untracked
                message = [message '&nbsp;&nbsp;<i><font color=rgb(255,69,0)>Modified and <font color="red">Untracked</font> Files</font></i>'];
            elseif modified
                message = [message '&nbsp;&nbsp;<font color=rgb(255,69,0)><i>Modified Files</i></font>'];
            elseif untracked
                message = [message '&nbsp;&nbsp;<font color="red"><i>Untracked Files</i></font>'];
            end
            
            str = ['<html><font color="blue"><b>' name '</b>&nbsp;&nbsp;<i>' hash '</i></font>' message];
        end
        function str = tooltip(obj)             % Fills the tooltip with git status + etc
            status = gitSafe('status --ahead-behind --show-stash');
            if strcmp(status(1:5), 'error') % Some installations of git  don't understand.
                status = gitSafe('status');
            end
            
            str_ = strrep(status, '/', ' / ');
            str__ = split(str_, newline);
            
            assert(~isempty(str__));
            
            str = ['On branch ' strrep(obj.thisbranch(), '/', ' / ') newline str_((numel(str__{1})+1):end)];
        end
    end
end

function str = makeHTML(str)    % Not rigorous
    str = strrep(str, '>', '&gt;');
    str = strrep(str, '<', '&lt;');
end

function out = gitSafe(str)
    [path,~,~] = fileparts(fileparts(mfilename('fullpath')));    % Two up from GitPanel; One up from +Base.
    
    oldPath = cd(path);
    
    out = git(str);
    
    cd(oldPath);
end