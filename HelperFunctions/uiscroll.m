function [ dataPanel,concealer ] = uiscroll( varargin )
%UISCROLL Allow a panel to be scrolled in y direction
%   Input is same as uipanel. All input is directed to the concealer panel.
%   Output is the dataPanel and concealer panel.
%
%   The concealer masks the potentially larger dataPanel. The user should
%   add stuff to the dataPanel as they wish.
%
%   dataPanel.UserData.top() will send you to the top of the dataPanel
%   
%   SQUEEZEPANEL can be used to easily adjust the panel to contain
%   everything. However, changing the size of the concealer will
%   automatically adjust the data to be the same width.
%
%   NOTE: If you change dataPanel.Units from normalized, that defeats the
%   purpose of a scroll bar!
%
%   NOTE: Remember the panel returned is not the one that varargin goes to.
%   You can change properties once the dataPanel is returned. Keep in mind
%   changing properties used by uiscroll will break it:
%       UserData.scroll
%       UserData.oldDelta
%       UserData.top()
%       ResizeFcn
%   You can add more UserData fields, just don't delete the existing ones!

% Parameters that could cause issues:
invalid = {'userdata','resizefcn'};
for i = 1:length(invalid)
    if sum(cellfun(@(a)strcmpi(invalid{i},a),varargin(1:2:end)))
        err = MException('MATLAB:hg:InvalidProperty',...
            sprintf('Cannot set %s property in uiscroll.',invalid{i}));
        throwAsCaller(err)
    end
end
% Take care of visible property (necessary because we don't want to
% evaluate ResizeFcn's until everything is made, or they will error.
visible = 'on';
vis = find(cellfun(@(a)strcmpi('visible',a),varargin(1:2:end)),1);
if ~isempty(vis)
    visible = varargin{vis+1};
    varargin(vis:vis+1) = [];
end

concealer = uipanel('ResizeFcn',@concealer_resize,'visible','off',varargin{:});
dataPanel = uipanel(concealer,...
    'DeleteFcn',@(src,~)delete(src.Parent),...
    'ResizeFcn',@dataPanel_resize,...
    'Units','pixels');%,'BorderType','none');

dataPanel.UserData.top = @()top(dataPanel);

s = uicontrol('Style','Slider','Parent',concealer,...
    'Units','normalized','Position',[0.95 0 0.05 1],...
    'Callback',@slider_callback);

% Prepare some data for callbacks
concealer.UserData.scroll = s;
dataPanel.UserData.scroll = s;
dataPanel.UserData.oldDelta = NaN;
concealer.UserData.dataPanel = dataPanel;
s.UserData.dataPanel = dataPanel;

if strcmpi(visible,'on')
    concealer.Visible = 'on';
end
end


%% Helpers
function top(dataPanel)
datPos = getpixelposition(dataPanel);
conPos = getpixelposition(dataPanel.Parent);  % Concealer
delta = datPos(4) - conPos(4);
datPos(2) = -(delta+1);
setpixelposition(dataPanel,datPos);
dataPanel.UserData.scroll.Value = -datPos(2);
end

%% Callbacks
function slider_callback(src,~)
val = get(src,'Value');
pos = getpixelposition(src.UserData.dataPanel);
pos(2) = -val;
setpixelposition(src.UserData.dataPanel,pos);
end

function dataPanel_resize(src,~)
% Only execute if height changed
assert(isvalid(src.UserData.scroll),'Scroll bar was deleted!')
datPos = getpixelposition(src);
conPos = getpixelposition(src.Parent);  % Concealer
% Calculate scroll bounds
delta = datPos(4) - conPos(4);
if src.UserData.oldDelta ~= delta
    src.UserData.oldDelta = delta;
    if delta > 0
        if -datPos(2) > delta+1
            % Top of data panel should remain at top
            datPos(2) = -(delta+1);
            setpixelposition(src,datPos);
        end
        set(src.UserData.scroll,'max',delta+1,'Value',max(-datPos(2),0))
        src.UserData.scroll.SliderStep = min([15,100]/(delta+1),1);
        if strcmp(src.UserData.scroll.Visible,'off')
            src.UserData.scroll.Visible = 'on';
            concealer_resize(src.Parent)
        end
    elseif strcmp(src.UserData.scroll.Visible,'on')
        src.UserData.scroll.Visible = 'off';
    end
end
end

function concealer_resize(src,~)
% Scrollbars are 20 pixels wide
assert(isvalid(src.UserData.scroll),'Scroll bar was deleted!')
assert(isvalid(src.UserData.dataPanel),'Data panel was deleted!')
if strcmp(src.UserData.scroll.Visible,'on')
    buffer = 20;
else
    buffer = 0;
end
pos = getpixelposition(src);
oldPos = getpixelposition(src.UserData.dataPanel);
newPos = oldPos;
newPos(3) = pos(3) - buffer;
if oldPos(3) ~= newPos(3)
    setpixelposition(src.UserData.dataPanel,newPos);
else % Force callback anyway
    dataPanel_resize(src.UserData.dataPanel)
end
end

