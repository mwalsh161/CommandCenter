classdef GitPanel
    
    properties
        panel;
        text;
        menu;
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
                f = varargin{2};
            else    % Ignore arguments otherwise
                f = figure;
                f.Position(3:4) = f.Position(3:4)/2;
            
                obj.panel = uipanel(f);
            end
            
            obj.panel.Title = 'git branch';
            obj.panel.Units = 'characters';
            obj.panel.Position(4) = 2;
            obj.panel.Visible = 'off';
            
            filedetails = ' &lt;file(s)&gt; (--all)';
            commitdetails = ' --author &lt;you&gt; --message &lt;description&gt;';
            
            obj.menu = uicontextmenu(f);
            uimenu(obj.menu, 'Label',  '<html><font color="purple">git fetch', 'Callback', @(s,e)obj.update)
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git status<br>'...
                                             '<font color="purple">git ad&d' filedetails '<br>'...
                                             '<font color="purple">git commit' commitdetails '<br>'...
                                             '<font color="purple">git push'], 'Callback', @(s,e)(disp('Add files to a commit, then commit, and push to save changes.')));
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git status<br>',...
                                             '<font color="purple">git pull'], 'Callback', @(s,e)(disp('Pull to stay up to date')))
            
            obj.panel.UIContextMenu = obj.menu; 
            
            obj.text = uicontrol(obj.panel, 'Style', 'checkbox', 'UIContextMenu', obj.menu, 'Units', 'characters', 'String', '...');     % Text does not display HTML :(
            obj.text.Position(1:2) = [-2.75 0];
            obj.text.Position(3) = 200;
            
            if (obj.enableLeftClick)
                obj.panel.ButtonDownFcn = @(s,e)(obj.update);
                obj.text.Callback = @(s,e)obj.update;
            end
            
            obj.update();
            
            obj.panel.Visible = 'on'; 
        end
        function update(obj)
            obj.panel.HighlightColor = [.5 0 .5];   % Purple
            obj.panel.Title = 'git fetch';
            try
                git('fetch -q --all');
                
                obj.text.String = 'Fetching...';
                drawnow;
                
                obj.text.Tooltip = obj.tooltip();
                obj.text.String = obj.info();
                obj.panel.HighlightColor = 'w';
                obj.panel.Title = 'git branch';
                drawnow;
            catch err
                obj.text.String = '<html>Could not <font color="purple">git fetch.';
                obj.text.Tooltip = 'Something terrible happened.';
                
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
                        message = ['&nbsp;&nbsp;<font color="orange">[' commas{1} ', <font color="red">' commas{2} ']'];% messageraw((numel(brackets{1})+3):end)];
                    
                    else
                        message = ['&nbsp;&nbsp;<font color="orange">[' brackets{1} ']'];% messageraw((numel(brackets{1})+3):end)];
                    end
                case '[behin'
                    message = ['&nbsp;&nbsp;<font color="red">[' brackets{1} ']'];% messageraw((numel(brackets{1})+3):end)];
                otherwise
            end
            
            status = git('status');
            
            modified = contains(status,'Changes not staged for commit:') || contains(status,'Changes to be committed:');
            untracked = contains(status,'Untracked files:');
            
            if modified && untracked
                message = [message '&nbsp;&nbsp;<I><font color=rgb(255,69,0)>Modified and <font color="red">Untracked Files</I>'];
            elseif modified
                message = [message '&nbsp;&nbsp;<font color=rgb(255,69,0)><I>Modified Files</I>'];
            elseif untracked
                message = [message '&nbsp;&nbsp;<font color="red"><I>Untracked Files</I>'];
            end
            
            str = ['<html><font color="blue"><B>' words{1} '</B>&nbsp;&nbsp;<I>' words{2} '</I>' message];
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