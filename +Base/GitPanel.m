classdef GitPanel
    
    properties
        panel;      % uipanel
        control;    % uicontrol that displays the current branch info. % For some reason, this property is empty from inside the object, but not from outside. Using panel.Children to access this uicontrol.
        menu;       % uicontextmenu to show useful git options.
    end
    
    properties (Constant)
        enableLeftClick = false
    end
    
    methods
        function obj = GitPanel(varargin)
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
            obj.panel.Position(4) = 2;
            
            filedetails = ' &lt;file(s)&gt; (--all)';
            commitdetails = ' --author &lt;you&gt; --message &lt;description&gt;';
            
            obj.menu = uicontextmenu(f);
            uimenu(obj.menu, 'Label',  '<html><font color="purple">git</font> fetch', 'Callback', @(s,e)obj.update)
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>'...
                                             '<font color="purple">git</font> ad&d' filedetails '<br>'...
                                             '<font color="purple">git</font> commit' commitdetails '<br>'...
                                             '<font color="purple">git</font> push origin <branch>'], 'Callback', @(s,e)(disp('Add files to a commit, then commit, and push to save changes.')));
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>',...
                                             '<font color="purple">git</font> pull'], 'Callback', @(s,e)(disp('Pull to stay up to date')))
            
            obj.panel.UIContextMenu = obj.menu; 
            
            obj.control = uicontrol('Parent', obj.panel, 'Style', 'checkbox', 'UIContextMenu', obj.menu, 'Units', 'characters', 'String', '', 'Tag', 'gitpanelcontrol');     % Text does not display HTML :(
            obj.control.Position(1:2) = [-2.75 0];
            obj.control.Position(3) = 200;
            
            if (obj.enableLeftClick)
                obj.panel.ButtonDownFcn = @(s,e)(obj.update);
                obj.control.Callback = @(s,e)obj.update;
            end
            
            obj.update();
        end
        function update(obj)
            obj.panel.Children.Enable = 'off';
            obj.panel.HighlightColor = [.5 0 .5];   % Purple
            obj.panel.Title = 'git fetch';
            drawnow;
            
            try
                git('fetch -q --all');
                
                obj.panel.Children.Tooltip = obj.tooltip();
                obj.panel.Children.String = obj.info();
                
                obj.panel.Children.Enable = 'on';
                obj.panel.HighlightColor = 'w';
                obj.panel.Title = 'git branch';
                drawnow;
            catch err
                obj.panel.Children.Enable = 'on';
                obj.panel.Children.String = '<html>Could not <font color="purple">git</font> fetch.';
                obj.panel.Children.Tooltip = 'Something terrible happened.';
                drawnow;
                
                rethrow(err);
            end
        end
        function thisbranch = thisbranch(obj) %#ok<MANU> It wasn't fetching properly when it was static.
            thisbranch = split(git('branch', '-v'), '* ');
            thisbranch = split(thisbranch{end}, newline);
            thisbranch = thisbranch{1};
        end
        function str = info(obj)
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

            third = words{3};
            
            test = '';
            if numel(third) >= 6
                test = third(1:6);
            end

            switch test
                case '[ahead'
                    commas = split(brackets{1}, {', '});
                    
                    if numel(commas) == 2
                        message = ['&nbsp;&nbsp;<font color="orange">[' commas{1} '</font>, <font color="red">' commas{2} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                    
                    else
                        message = ['&nbsp;&nbsp;<font color="orange">[' brackets{1} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                    end
                case '[behin'
                    message = ['&nbsp;&nbsp;<font color="red">[' brackets{1} ']</font>'];% messageraw((numel(brackets{1})+3):end)];
                otherwise
            end
            
            status = git('status');
            
            modified = contains(status,'Changes not staged for commit:') || contains(status,'Changes to be committed:');
            untracked = contains(status,'Untracked files:');
            
            if modified && untracked
                message = [message '&nbsp;&nbsp;<I><font color=rgb(255,69,0)>Modified and <font color="red">Untracked</font> Files</font></I>'];
            elseif modified
                message = [message '&nbsp;&nbsp;<font color=rgb(255,69,0)><I>Modified Files</I></font>'];
            elseif untracked
                message = [message '&nbsp;&nbsp;<font color="red"><I>Untracked Files</I></font>'];
            end
            
            str = ['<html><font color="blue"><B>' words{1} '</B>&nbsp;&nbsp;<I>' words{2} '</I></font>' message];
        end
        function str = tooltip(obj)
            str_ = strrep(git('status --ahead-behind --show-stash'), '/', ' / ');
            str__ = split(str_, newline);
            
            assert(~isempty(str__));
            
            str = ['On branch ' obj.thisbranch() newline str_((numel(str__{1})+1):end)];
        end
    
    end
end

function str = makeHTML(str)    % Not rigorous
    str = strrep(str, '>', '&gt;');
    str = strrep(str, '<', '&lt;');
end