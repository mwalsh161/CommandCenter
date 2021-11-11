function [ h ] = add_button( button_to_left,string )
%ADD_BUTTON Given the handle to a button to the left, create another next
%to it
%   Duplicate button will have same dimensions. Attributes should be set
%   with returned handle.

d = 10; % points spacing
sz = button_to_left.Position;
parent = button_to_left.Parent;
h = uicontrol(parent,'units','points','style','pushbutton',...
    'position',[sz(1)+sz(3)+d sz(2:4)],'string',string);
h.Position(3) = h.Extent(3)+sz(3) - button_to_left.Extent(3);

end

