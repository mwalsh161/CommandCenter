function [ui,btn] = listbox(parent,confirmation,varargin)
%LISTBOX uicontrol style=listbox with confirm button at bottom
%   Blocks until confirmation button pressed
%       Override with parent.UserData.uiwait = false
%   varargin input is piped to uicontrol;
%       position and style ignored
%   return [uicontrol, button] handles

buttonHeight = 2; % characters

ui = uicontrol(parent,varargin{:});
ui.Style = 'listbox';
% Fill parent container
parent.Units = 'characters';
ui.Units = parent.Units;
ui.Position = [0 0 parent.Position(3:4)];
ui.Position([2,4]) = ui.Position([2,4])+[1 -1]*buttonHeight*1.1;
btn = uicontrol(parent,'style','pushbutton','string',confirmation,...
    'units','characters','callback','uiresume(gcbf)');
btn.Position([1,3]) = [1 parent.Position(3)-2];
btn.Position(2) = buttonHeight*0.05;
btn.Position(4) = buttonHeight;

% Make a tad resizable...
ui.Units = 'normalized';
btn.Units = 'normalized';
parent.Visible = 'on';
if ~(isfield(parent.UserData,'uiwait') && ~parent.UserData.uiwait)
    uiwait(parent);
end
end

