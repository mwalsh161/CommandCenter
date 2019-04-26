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
%       AxisPositions: position in figure's current axis
%           - if no axis, it will be NaN(0,2)
%       TargetObj: the target supplied to MOUSETRACK
%   UserData begins is empty array, but can be anything; useful to persist
%       data between callbacks. It is an optional return argument.
%   INPUT [name] indicates name,value parameters:
%       target: a graphics object the user wishes to click on
%       [start_fcn]: see above
%       [update_fcn]: see above
%       [stop_fcn]: see above
%   OUTPUT:
%       figure: the parent figure used
%       output: the output returned by stop_fcn (if supplied, mouseTrack is
%           a blocking operation)
%   NOTE: upon releasing click; all callbacks are restored, so this
%       function needs to be called each time this should happen
%   NOTE: nargout(stop_fcn) > 0 is used to determine if output exists and
%       call is blocking; this means it needs to be explicit; varargout will
%       not work.
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
    addParameter(p,'start_fcn','',@(x)isa(x,'function_handle'));
    addParameter(p,'update_fcn','',@(x)isa(x,'function_handle'));
    addParameter(p,'stop_fcn','',@(x)isa(x,'function_handle'));
end
parse(p,target,varargin{:});
fig = Base.getParentFigure(target);
ax = fig.CurrentAxes;

% Can use global function scope since only one evaluation will happen at a time
Output = [];
UserData = [];
Positions = NaN(0,2);
AxisPositions = NaN(0,2);
last_WindowButtonMotionFcn = fig.WindowButtonMotionFcn;
last_WindowButtonUpFcn = fig.WindowButtonUpFcn;
last_ButtonDownFcn = target.ButtonDownFcn;
% Set callback that starts everything
target.ButtonDownFcn = @startTrack;
if ~isempty(p.Results.stop_fcn) && nargout(p.Results.stop_fcn) > 0
    uiwait(fig); % Blocking call if stop_fcn has output
end
    function startTrack(hObj,eventdata)
        % Link button up first in case start_fcn errors
        fig.WindowButtonUpFcn = @stopTrack;
        warning('off','MATLAB:structOnObject')
        Positions(end+1,:) = get(fig,'CurrentPoint');
        if ~isempty(ax)
             cpt = get(ax,'CurrentPoint');
             AxisPositions(end+1,:) = cpt(1,1:2);
        end
        if ~isempty(p.Results.start_fcn)
            eventdata = struct(eventdata);
            eventdata.Positions = Positions;
            eventdata.AxisPositions = AxisPositions;
            eventdata.TargetObj = target;
            if nargout(p.Results.start_fcn) > 0
                UserData = p.Results.start_fcn(hObj,eventdata);
            else
                p.Results.start_fcn(hObj,eventdata);
            end
        end
        % Finish linking callbacks now that we have engaged
        fig.WindowButtonMotionFcn = @track;
    end
    function track(hObj,eventdata)
        Positions(end+1,:) = get(fig,'CurrentPoint');
        if ~isempty(ax)
             cpt = get(ax,'CurrentPoint');
             AxisPositions(end+1,:) = cpt(1,1:2);
        end
        if ~isempty(p.Results.update_fcn)
            eventdata = struct(eventdata);
            eventdata.Positions = Positions;
            eventdata.AxisPositions = AxisPositions;
            eventdata.TargetObj = target;
            if nargout(p.Results.update_fcn) > 0
                UserData = p.Results.update_fcn(hObj,eventdata,UserData);
            else
                p.Results.update_fcn(hObj,eventdata,UserData);
            end
        end
    end
    function stopTrack(hObj,eventdata)
        fig.WindowButtonMotionFcn = last_WindowButtonMotionFcn;
        fig.WindowButtonUpFcn = last_WindowButtonUpFcn;
        target.ButtonDownFcn = last_ButtonDownFcn;
        if ~isempty(p.Results.stop_fcn)
            Positions(end+1,:) = get(fig,'CurrentPoint');
            if ~isempty(ax)
                cpt = get(ax,'CurrentPoint');
                AxisPositions(end+1,:) = cpt(1,1:2);
            end
            eventdata = struct(eventdata);
            eventdata.Positions = Positions;
            eventdata.AxisPositions = AxisPositions;
            eventdata.TargetObj = target;
            try
                if nargout(p.Results.stop_fcn) > 0
                    Output = p.Results.stop_fcn(hObj,eventdata,UserData);
                else
                    p.Results.stop_fcn(hObj,eventdata,UserData);
                end
            catch err
                warning('off','MATLAB:structOnObject')
                uiresume(fig); % harmless to call if not waiting
                rethrow(err)
            end
        end
        warning('on','MATLAB:structOnObject')
        uiresume(fig);
    end

varargout = {fig,Output};
varargout = varargout(1:nargout);
end