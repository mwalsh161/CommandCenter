function updateprop(hObj,eventdata,listener_obj,varargin)
%UPDATEPROP Callback to update class properties from PostSet
%   updateprop(hObj,eventdata,listener_obj)
%       listener_obj: handle to listener class
%   updateprop(hObj,eventdata,prop_name)
%       prop_name: name of corresponding property in the class listening
%           if not the same as listenee class

if isempty(varargin)
    prop = hObj.Name;
else
    prop = varargin{1};
end
listener_obj.(prop) = eventdata.AffectedObject.(hObj.Name);
end

