function varargout = mouseTrack(target,varargin)
%MOUSETRACK Evaluate callbacks when moving mouse while button held on target
%   When user clicks on a target graphic object, this will call:
%       [UserData] = start_fcn(target,eventdata) when first clicked
%       [UserData] = update_fcn(figure,eventdata,UserData) while mouse moves
%       [output] = stop_fcn(figure,eventdata,UserData) when mouse button released
%           - NOTE: if output is supplied here; mouseTrack turns into a
%           blocking call and returns output
%   eventdata is the typical eventdata for these actions but with the
%   following fields appended:
%       Positions: a vector of all positions from start to current
%       AxisPositions: position in figure's current axis or target's
%          closest parent.
%           - if no axis, it will be NaN(0,2)
%       TargetObj: the target supplied to MOUSETRACK
%   UserData begins is empty array, but can be anything; useful to persist
%       data between callbacks. It is an optional return argument.
%   INPUT (argument) indicates optional positional arg [name] indicates name,value parameters:
%       target: a graphics object the user wishes to click on
%       (reset): Value of "reset" will remove functionality regardless of
%          what 'n' is. Default value is 1.
%       [start_fcn]: see above
%       [update_fcn]: see above
%       [stop_fcn]: see above
%       [n]: number of times to allow interaction (default Inf)
%   OUTPUT:
%       figure: the parent figure used
%       output: the output returned by stop_fcn (if supplied, mouseTrack is
%           a blocking operation)
%   NOTE: upon releasing click; all callbacks are restored, so this
%       function needs to be called each time this should happen
%   NOTE: nargout(stop_fcn) > 0 is used to determine if output exists and
%       call is blocking; this means it needs to be explicit; varargout will
%       not work.
%   NOTE: This method will use target.UserData.mouseTrack if available
%       otherwise error.
%   NOTE: Keep in mind other graphics above the target will only pass the
%      click through if their 'HitTest' property is 'off'
%
%   EXAMPLES:
%       >> f = figure; ax = axes;
%     - Print out location in figure (pixel units):
%       >> mouseTrack(f,'update_fcn',...
%               @(~,b,~)fprintf('%i, %i\n',b.Positions(end,:)))
%     - Print out location in axes (axis units):
%       >> mouseTrack(ax,'update_fcn',...
%               @(a,b)fprintf('%i, %i\n',b.AxisPositions(end,:)))
%     - Draw a box on axes (using the UserData to store data between callbacks):
%       >> mouseTrack(ax,'start_fcn',@makeRect,'update_fcn',@updateRect,'stop_fcn',@done)
%          function rect = makeRect(ax,eventdata)
%              pos = eventdata.AxisPositions(1,:);
%              rect = patch(ax,'vertices',[pos;pos;pos;pos],...
%                  'faces',[1,2,3,4],'facealpha',0);
%          end
%          function updateRect(~,eventdata,rect)
%              pos = eventdata.AxisPositions(end,:);
%              rect.Vertices(2:4,:) = [eventdata.AxisPositions(1,1), pos(2);...
%                                      pos;...
%                                      pos(1), eventdata.AxisPositions(1,2)];
%          end
%          function done(~,~,rect)
%              delete(rect);
%          end
%     - Draw a freeform line (Note axis settings necessary to prevent resizing
%       while drawing):
%       >> f = figure; ax = axes('XLimMode','manual','YLimMode','manual'); hold(ax,'on');
%       >> mouseTrack(ax,'start_fcn', @makeLine,...
%            'update_fcn',@(~,a,ln)set(ln,...
%                      'XData',[get(ln,'XData'),a.AxisPositions(end,1)],...
%                      'YData',[get(ln,'YData'),a.AxisPositions(end,2)]),...
%            'stop_fcn',  @(~,~,ln)delete(ln));
%           function line = makeLine(ax,eventdata)
%               pos = eventdata.AxisPositions(1,:);
%               line = plot(ax,pos(1),pos(2));
%           end

persistent p
if isempty(p) % Avoid having to rebuild on each function call
    p = inputParser();
    addRequired(p,'target',@isvalid);
    addOptional(p,'reset','',@(x)any(validatestring(x,{'reset'})));
    addParameter(p,'start_fcn','',@(x)isa(x,'function_handle'));
    addParameter(p,'update_fcn','',@(x)isa(x,'function_handle'));
    addParameter(p,'stop_fcn','',@(x)isa(x,'function_handle'));
    addParameter(p,'n',1,@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
end
parse(p,target,varargin{:});
assert(isinf(p.Results.n)||isinteger(p.Results.n),"The value of 'n' is invalid. Expected input to be integer-valued or Inf.")
if ~isempty(p.Results.reset)
    clean_up(target);
    return
end
if isstruct(target.UserData) && isfield(target.UserData,'mouseTrack')
    error('Target already has a mouseTrack field in UserData.')
elseif ~isstruct(target.UserData) && ~isempty(target.UserData)
    error('Target UserData is not a struct and is not empty.')
end
fig = Base.getParentFigure(target);
ax = get_axes(target);
if isempty(ax)
    ax = fig.CurrentAxes; % This can also be empty
end

handles.args = struct(p.Results);
handles.fig = fig;
handles.ax = ax;
handles.Output = [];
handles.UserData = [];
handles.Positions = NaN(0,2);
handles.AxisPositions = NaN(0,2);
handles.last_WindowButtonMotionFcn = fig.WindowButtonMotionFcn;
handles.last_WindowButtonUpFcn = fig.WindowButtonUpFcn;
handles.last_ButtonDownFcn = target.ButtonDownFcn;
target.UserData.mouseTrack = handles;
% Set callback that starts everything
target.ButtonDownFcn = @startTrack;
if ~isempty(p.Results.stop_fcn) && nargout(p.Results.stop_fcn) > 0
    uiwait(fig); % Blocking call if stop_fcn has output
end

varargout = {fig,handles.Output};
varargout = varargout(1:nargout);
end

%%% Callback functions
function clean_up(target)
if isstruct(target.UserData) && isfield(target.UserData,'mouseTrack')
    handles = target.UserData.mouseTrack;
    warning('off','MATLAB:structOnObject')
    uiresume(handles.fig); % harmless to call if not waiting
    handles.fig.WindowButtonMotionFcn = handles.last_WindowButtonMotionFcn;
    handles.fig.WindowButtonUpFcn = handles.last_WindowButtonUpFcn;
    target.ButtonDownFcn = handles.last_ButtonDownFcn;
    target.UserData = rmfield(target.UserData,'mouseTrack');
end
end
function startTrack(target,eventdata)
handles = target.UserData.mouseTrack;
% Link button up first in case start_fcn errors
handles.fig.WindowButtonUpFcn = {@stopTrack,target};
warning('off','MATLAB:structOnObject')
handles.Positions(end+1,:) = get(handles.fig,'CurrentPoint');
if ~isempty(handles.ax)
    cpt = get(handles.ax,'CurrentPoint');
    handles.AxisPositions(end+1,:) = cpt(1,1:2);
end
if ~isempty(handles.args.start_fcn)
    eventdata = struct(eventdata);
    eventdata.Positions = handles.Positions;
    eventdata.AxisPositions = handles.AxisPositions;
    eventdata.TargetObj = target;
    if nargout(handles.args.start_fcn) > 0
        handles.UserData = handles.args.start_fcn(target,eventdata);
    else
        handles.args.start_fcn(target,eventdata);
    end
end
handles.args.n = handles.args.n - 1;
target.UserData.mouseTrack = handles;
% Finish linking callbacks now that we have engaged
handles.fig.WindowButtonMotionFcn = {@track,target};
end

function track(fig,eventdata,target)
handles = target.UserData.mouseTrack;
handles.Positions(end+1,:) = get(fig,'CurrentPoint');
if ~isempty(handles.ax)
    cpt = get(handles.ax,'CurrentPoint');
    handles.AxisPositions(end+1,:) = cpt(1,1:2);
end
if ~isempty(handles.args.update_fcn)
    eventdata = struct(eventdata);
    eventdata.Positions = handles.Positions;
    eventdata.AxisPositions = handles.AxisPositions;
    eventdata.TargetObj = target;
    if nargout(handles.args.update_fcn) > 0
        handles.UserData = handles.args.update_fcn(fig,eventdata,handles.UserData);
    else
        handles.args.update_fcn(fig,eventdata,handles.UserData);
    end
end
target.UserData.mouseTrack = handles;
end

function stopTrack(fig,eventdata,target)
handles = target.UserData.mouseTrack;
err = [];
if ~isempty(handles.args.stop_fcn)
    handles.Positions(end+1,:) = get(fig,'CurrentPoint');
    if ~isempty(handles.ax)
        cpt = get(handles.ax,'CurrentPoint');
        handles.AxisPositions(end+1,:) = cpt(1,1:2);
    end
    eventdata = struct(eventdata);
    eventdata.Positions = handles.Positions;
    eventdata.AxisPositions = handles.AxisPositions;
    eventdata.TargetObj = target;
    try
        if nargout(handles.args.stop_fcn) > 0
            handles.Output = handles.args.stop_fcn(target,eventdata,handles.UserData);
        else
            handles.args.stop_fcn(fig,eventdata,handles.UserData);
        end
    catch err
    end
end
if handles.args.n == 0
    clean_up(target);
else % Suspend button motion fcn until click again and reset vectors
    handles.fig.WindowButtonMotionFcn = [];
    handles.Positions = NaN(0,2);
    handles.AxisPositions = NaN(0,2);
    target.UserData.mouseTrack = handles;
end
if ~isempty(err)
    rethrow(err);
end
end

%%% Helper functions
function obj = get_axes(obj)
% Given a descendant of an axes, return the axes
while ~isempty(obj) && ~strcmp('axes', get(obj,'type'))
  obj = get(obj,'parent');
end
if ~strcmp('axes', get(obj,'type'))
    obj = [];
end
end