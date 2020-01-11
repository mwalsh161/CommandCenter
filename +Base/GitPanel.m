classdef GitPanel
    
    properties
        panel = [];
        text = [];
        menu = [];
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
            
%             '<sup>--author **you**</sup> <sub>--message **decription**</sub>'
            filedetails = ' &lt;file(s)&gt; (--all)';
            commitdetails = ' --author &lt;you&gt; --message &lt;description&gt;';
            
            obj.menu = uicontextmenu(f);
            uimenu(obj.menu, 'Label',  '<html><font color="purple">git</font> fetch</html>', 'Callback', @(s,e)obj.update)
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>'...
                                             '<font color="purple">git</font> ad&d' filedetails '<br>'...
                                             '<font color="purple">git</font> commit' commitdetails '<br>'...
                                             '<font color="purple">git</font> push</html>'], 'Callback', @(s,e)(disp('Add files to a commit, then commit, and push to save changes.')));
            uimenu(obj.menu, 'Label', ['<html><font color="purple">git</font> status<br>',...
                                             '<font color="purple">git</font> pull</html>'], 'Callback', @(s,e)(disp('Pull to stay up to date')))
            
            obj.panel.UIContextMenu = obj.menu;
            
            obj.text = uicontrol(obj.panel, 'Style', 'radiobutton', 'UIContextMenu', obj.menu, 'Units', 'characters');
            obj.text.Position(1:2) = [-2.75 0];
            obj.text.Position(3) = 200;
            
            if (obj.enableLeftClick)
                obj.panel.ButtonDownFcn = @(s,e)(obj.update);
                obj.text.Callback = @(s,e)obj.update;
            end
            
            obj.update();
        end
        
        function update(obj)
            obj.panel.HighlightColor = [.5 0 .5];   % Purple
            drawnow;
            try
                git('fetch -q --all');
            
                obj.text.String = obj.info();
                obj.text.Tooltip = obj.tooltip();
                obj.panel.HighlightColor = 'w';
                drawnow;
            catch err
                obj.text.String = '<html>Could not <font color="purple">git</font> fetch.';
                obj.text.Tooltip = 'Something terrible happened.';
                
                rethrow(err);
            end
        end
    end
    methods (Static)
        function outofdate()
            
        end
        function thisbranch = thisbranch()
            thisbranch = split(git('branch', '-v'), '* ');
            thisbranch = split(thisbranch{end}, newline);
            thisbranch = thisbranch{1};
            
%             thisbranch = 'measurement aa2a21d [ahead 6] Finished rename of files. More commenting and cleanup.';
        end
        function str = info()
            thisbranch = makeHTML(Base.GitPanel.thisbranch());
            
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
            
            if contains(status,'Changes not staged for commit:') || contains(status,'Changes to be committed:')
                message = [message '&nbsp;&nbsp;<font color=orange><I>Modified Files</I></font>'];
            end
            
            if contains(status,'Untracked files:')
                message = [message '&nbsp;&nbsp;<font color="red"><I>Untracked Files</I></font>'];
            end
            
            str = {['<html><font color="blue"><B>' words{1} '</B>&nbsp;&nbsp;<I>' words{2} '</I></font>' message '</html>'], 'Untracked'};
        end
        function str = tooltip()
            str_ = strrep(git('status --ahead-behind --show-stash'), '/', ' / ');
            str__ = split(str_, newline);
            
            assert(~isempty(str__));
            
            str = ['On branch ' Base.GitPanel.thisbranch() newline str_((numel(str__{1})+1):end)];
        end
    
    end
end

function str = makeHTML(str)    % Not rigorous
    str = strrep(str, '>', '&gt;');
    str = strrep(str, '<', '&lt;');
end