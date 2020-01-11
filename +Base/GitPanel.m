classdef GitPanel
    
    properties
        panel = [];
        text = [];
        dots = [];
        menu = [];
    end
    
    methods
        function obj = GitPanel(varargin)
            f = figure;
            f.Position(3:4) = f.Position(3:4)/1.8;
            
            obj.panel = uipanel(f, 'Title', 'git branch', 'Units', 'characters');
            obj.panel.Position(4) = 2;
            
            obj.menu = uicontextmenu();
            uimenu(obj.menu, 'Label', '<html><font color="purple">git</font> add .<br><font color="purple">git</font> commit</html>')
            uimenu(obj.menu, 'Label', '<html><font color="purple">git</font> push')
            uimenu(obj.menu, 'Label', '<html><font color="purple">git</font> pull')
            obj.text = uicontrol(obj.panel, 'Style', 'radiobutton', 'UIContextMenu', obj.menu, 'Units', 'characters', 'Callback', @(s,e)obj.update);
            obj.text.Position(1:2) = [-2.75 0];
            obj.text.Position(3) = 10000;
            
%             obj.dots = uicontrol(obj.panel, 'Style', 'text', 'String', ' ...     ', 'UIContextMenu', obj.menu, 'Units', 'characters');
            obj.dots.Position(1:2) = [obj.panel.Position(3)-2.5 0];
            obj.dots.Position(3) = 3;
            
            obj.update();
        end
        
        function update(obj)
            [obj.text.String, message] = obj.info();
            obj.text.Tooltip = obj.tooltip(message);
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
        function [str, messageraw] = info()
            thisbranch = Base.GitPanel.thisbranch();
            
            words_ = split(thisbranch, ' ');
            words = {};
            
            jj = 1;
            for ii = 1:length(words_)
                if ~isempty(words_{ii})
                    words{jj} = words_{ii};
                    jj = jj + 1;
                end
            end

            third = words{3};
            
            test = '';
            if numel(third) >= 6
                test = third(1:6);
            end
            
            message_ = split(thisbranch, words{2});
            messageraw = strtrim(message_{end});
            
            brackets = split(messageraw, {'[', ']'});
            
            while ~isempty(brackets) && isempty(brackets{1})
                brackets(1) = [];
            end
            
            message = '';

            switch test
                case '[ahead'
                    commas = split(brackets{1}, {', '});
                    
                    if numel(commas) == 2
                        message = ['&nbsp;&nbsp;[<font color="orange">' commas{1} '</font>, <font color="red">' commas{2} '</font>]'];% messageraw((numel(brackets{1})+3):end)];
                    
                    else
                        message = ['&nbsp;&nbsp;[<font color="orange">' brackets{1} '</font>]'];% messageraw((numel(brackets{1})+3):end)];
                    end
                case '[behin'
                    message = ['&nbsp;&nbsp;[<font color="red">' brackets{1} '</font>]'];% messageraw((numel(brackets{1})+3):end)];
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
        function str = tooltip(message)
            str_ = strrep(git('status'), '/', ' / ');
            str__ = split(str_, newline);
            
            assert(~isempty(str__));
            
            str = ['On branch ' Base.GitPanel.thisbranch() newline str_((numel(str__{1})+1):end)];
%             str
%             str = ['<html><font face="Courier">' git('status') '</font></html>'];
        end
    
    end
end