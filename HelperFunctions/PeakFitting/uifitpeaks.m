function varargout = uifitpeaks(ax,varargin)
%UIFITPEAKS Graphical/interactive version of fitpeaks
%   Takes all data in axes. User clicks to apply new guesses for peaks and
%   can modify existing guesses
%   Inputs (optional):
%       [FitType]: "gauss" or "lorentz" (default "guass")
%       [Bounds]: How tight to make bounds on fit; [lower,upper] = Bounds*initial guess
%       [StepSize]: Pixels to increment when moving guess with arrows
%   Outputs:
%       pFit: line object corresponding to fitted line
%           UserData of this line is the cfit object
%           Deleting this line cleans up all uifitpeaks graphics and
%             listeners, restoring the original figure and axes callbacks

p = inputParser;
addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'Bounds',[0,2],@(x) isnumeric(x) && ismatrix(x) && length(x)==2);
addParameter(p,'StepSize',10,@(x) isnumeric(x) && numel(x)==1);
parse(p,varargin{:});
fittype = lower(p.Results.FitType);

x = [];
y = [];
children = [findall(ax,'type','line') findall(ax,'type','scatter')];
for i = 1:length(children)
    if ~strcmp(get(children(i),'tag'),mfilename)
        x = [x; children(i).XData'];
        y = [y; children(i).YData'];
        set(children(i),'HitTest','off');
    end
end

% Init with fitpeaks
colors = lines;
xfit = linspace(min(x),max(x),1001);
[vals,confs,fits,~,init] = fitpeaks(x,y,'FitType',fittype,'noisemodel','empirical');
held = ishold(ax);
hold(ax,'on');
if ~isempty(fits{end})
    bg = fits{end}.d; % Background
    pFit = plot(ax,xfit,fits{end}(xfit),'r','linewidth',1,'tag',mfilename);
else
    bg = median(y);
    pFit = plot(ax,xfit,ones(size(xfit))*bg,'r','linewidth',1,'tag',mfilename);
end
pFit.UserData = fits{end};

if ~held
    hold(ax,'off');
end
handles.Bounds = p.Results.Bounds;
handles.StepSize = p.Results.StepSize;
handles.pFit = pFit;
handles.x = x;
handles.y = y;
handles.lock = false;
switch fittype
    case 'gauss'
        handles.fit_function = @gaussfit;
    case 'lorentz'
        handles.fit_function = @lorentzfit;
end
handles.guesses = struct('gobs',{});
handles.colors = colors;

for i = 1:length(vals.locations) % vals tells us how many init points we took
    pnt(1) = addPoint(ax,init.locations(i),bg+init.amplitudes(i),isnan(confs.amplitudes(i)),colors(i,:));
    pnt(2) = addPoint(ax,init.locations(i)+init.widths(i),bg+init.amplitudes(i)/2,isnan(confs.widths(i)),colors(i,:));
    pnt(3) = addPoint(ax,init.locations(i)-init.widths(i),bg+init.amplitudes(i)/2,isnan(confs.widths(i)),colors(i,:));
    handles.guesses(end+1).gobs = pnt;
    pnt(1).UserData.ind = i;
    pnt(1).UserData.desc = 1; % encode amplitude (also index to guesses)
    pnt(2).UserData.ind = i;
    pnt(2).UserData.desc = 2; % encode right
    pnt(3).UserData.ind = i;
    pnt(3).UserData.desc = 3; % encode left
end
pnt = addPoint(ax,(max(x)+min(x))/2,bg,false,[0 0 0]);
pnt.UserData.ind = NaN;
pnt.UserData.desc = 0; % background
handles.background = pnt;

f = Base.getParentFigure(ax);
if isfield(f.UserData,[mfilename '_count'])
    f.UserData.([mfilename '_count']) = f.UserData.([mfilename '_count']) + 1;
else
    f.UserData.([mfilename '_count']) = 1;
end
handles.figure = f;
if f.UserData.([mfilename '_count']) == 1
    % Only remember if this is the first time called on a figure
    handles.old_keypressfcn = get(f,'keypressfcn');
    handles.old_keyreleasefcn = get(f,'keyreleasefcn');
    set(f,'keypressfcn',@shifted);
    set(f,'keyreleasefcn',@refit);
end
handles.old_buttondownfcn = get(ax,'buttondownfcn');
set(ax,'buttondownfcn',@newPeak);
ax.UserData = handles;
ax.UserData.([mfilename '_enabled']) = true;
ax.UserData.original_color = ax.Color;
iptPointerManager(f, 'enable');
addlistener(pFit,'ObjectBeingDestroyed',@clean_up);
if nargout
    varargout = {pFit};
end
end

function refit(hObj,varargin)
ax = gca;
if ~isstruct(ax.UserData) || ~isfield(ax.UserData,[mfilename '_enabled'])
    return;
end
if ax.UserData.lock
    return
end
handles = ax.UserData;
limit = handles.Bounds;
ax.UserData.lock = true;
try
handles.pFit.YData = median(handles.y)+zeros(size(handles.pFit.XData));
init = struct('background',handles.background.YData,'amplitudes',NaN(0,1),'locations',NaN(0,1),'widths',NaN(0,1));
n = length(handles.guesses);
if n==0 % Edge case of no peaks
    handles.lock = false;
    ax.UserData = handles;
    return
end
for i = 1:n % The notation below explicitly forces to column vector
    init.amplitudes(end+1,:) = handles.guesses(i).gobs(1).YData - handles.background.YData;
    init.widths(end+1,:) = abs(diff([handles.guesses(i).gobs([2,3]).XData]));
    init.locations(end+1,:) = handles.guesses(i).gobs(1).XData;
end
limits.amplitudes = [min(init.amplitudes)*limit(1) max(init.amplitudes)*limit(2)];
limits.widths = [min(init.widths)*limit(1) max(init.widths)*limit(2)];
limits.locations = [min(handles.x) max(handles.x)];
limits.background = [0 init.background*limit(2)];
f = handles.fit_function(handles.x, handles.y,n,init,limits);
handles.pFit.YData = f(handles.pFit.XData);
handles.pFit.UserData = f;
% Find all railed coefs
fitconfs = diff(confint(f));
[inds,descs] = meshgrid(1:n,1:3);
descs = descs(:); inds = inds(:);
for i = 1:3*n
    if isnan(fitconfs(i))
        handles.guesses(inds(i)).gobs(descs(i)).Marker = 'square';
    else
        handles.guesses(inds(i)).gobs(descs(i)).Marker = 'o';
    end
end
if isnan(fitconfs(end)) % Background
    handles.background.Marker = 'square';
else
    handles.background.Marker = 'o';
end
if any(isnan(fitconfs))
    set(ax,'Color',[1 0.8 0.8]);
else
    set(ax,'Color',[1 1 1]);
end
catch err
end
drawnow;
handles.lock = false;
ax.UserData = handles;
if exist('err','var')
    rethrow(err);
end
end

%% UI Callbacks
function clean_up(hObj,~)
ax = hObj.Parent;
handles = ax.UserData;
if isfield(handles,'old_keypressfcn')
    set(handles.figure,'keypressfcn',handles.old_keypressfcn);
end
if isfield(handles,'old_keyreleasefcn') % Using key release allows holding arrows to adjust faster
    set(handles.figure,'keyreleasefcn',handles.old_keyreleasefcn);
end
set(ax,'buttondownfcn',handles.old_buttondownfcn);
ax.Color = handles.original_color;
delete(findall(ax,'tag',mfilename))
handles.figure.UserData.([mfilename '_count']) = handles.figure.UserData.([mfilename '_count']) - 1;
end

function selected(hObj,~)
ax = gca;
if ~isstruct(ax.UserData) || ~isfield(ax.UserData,[mfilename '_enabled'])
    return;
end
set(findall(hObj.Parent,'tag',mfilename),'linewidth',1);
set(hObj,'linewidth',2);
ax.UserData.active_point = hObj;
end

function shifted(hObj,eventdata)
ax = gca;
if ~isstruct(ax.UserData) || ~isfield(ax.UserData,[mfilename '_enabled'])
    return;
end
handles = ax.UserData;
if isempty(handles.active_point)
    return
end
modified = false;
switch eventdata.Key
    case 'rightarrow'
        dir = 1;
    case 'uparrow'
        dir = 1;
    case 'leftarrow'
        dir = -1;
    case 'downarrow'
        dir = -1;
    case {'delete','backspace'}
        modified = true;
        ind = handles.active_point.UserData.ind;
        delete(handles.guesses(ind).gobs);
        handles.guesses(ind) = [];
        for i = ind:length(handles.guesses)
            for j = 1:length(handles.guesses(i).gobs)
            handles.guesses(i).gobs(j).UserData.ind = ...
                handles.guesses(i).gobs(j).UserData.ind - 1;
            end
        end
        handles.active_point = [];
end
[dx,dy] = pixel2coord(ax,handles.StepSize,handles.StepSize); %[x, y]
if ismember(eventdata.Key,{'leftarrow','rightarrow'})
    if any(handles.active_point.UserData.desc==[0,1,2,3])
        modified = true;
        dx = dx*dir;
        handles.active_point.XData = handles.active_point.XData + dx;
        if any(handles.active_point.UserData.desc==[2,3])
            other_ind = not(handles.active_point.UserData.desc==[2,3]);
            other = [2,3]; other = other(other_ind); % MATLAB annoying syntax
            handles.guesses(handles.active_point.UserData.ind).gobs(other).XData = ...
                handles.guesses(handles.active_point.UserData.ind).gobs(other).XData - dx;
        elseif handles.active_point.UserData.desc == 1
            handles.guesses(handles.active_point.UserData.ind).gobs(2).XData = ...
                handles.guesses(handles.active_point.UserData.ind).gobs(2).XData + dx;
            handles.guesses(handles.active_point.UserData.ind).gobs(3).XData = ...
                handles.guesses(handles.active_point.UserData.ind).gobs(3).XData + dx;
        end
        if handles.active_point.UserData.desc==0 % Lateral movement of background
            modified = false;
        end
    end
elseif ismember(eventdata.Key,{'uparrow','downarrow'})
    if any(handles.active_point.UserData.desc==[0,1])
        modified = true;
        dy = dy*dir;
        handles.active_point.YData = handles.active_point.YData + dy;
        if handles.active_point.UserData.desc == 1
            handles.guesses(handles.active_point.UserData.ind).gobs(2).YData = ...
                handles.guesses(handles.active_point.UserData.ind).gobs(2).YData + dy/2;
            handles.guesses(handles.active_point.UserData.ind).gobs(3).YData = ...
                handles.guesses(handles.active_point.UserData.ind).gobs(3).YData + dy/2;
        end
    end
end
if modified
    ax.UserData = handles;
end
end
%% Helpers
function [dx,dy] = pixel2coord(ax,dx_px,dy_px)
p = getpixelposition(ax);
xspan = diff(get(ax,'xlim'));
yspan = diff(get(ax,'ylim'));
dx = dx_px*xspan/p(3);
dy = dy_px*yspan/p(4);
end

function p = addPoint(ax,x,y,railed,color)
held = ishold(ax);
hold(ax,'on');
p = plot(ax,x,y,'color',color,'marker','o','linestyle','none','tag',mfilename,'linewidth',1);
if railed
    p.Marker = 'square';
    p.Color = p.Color*0.7;
end
if ~held
    hold(ax,'off');
end
set(p,'buttondownfcn',@selected);
end

function newPeak(hObj,eventdata)
ax = gca;
if ax.UserData.lock
    return
end
handles = ax.UserData;
if strcmp(handles.figure.SelectionType,'normal')
    return % Only use double click
end
bg = handles.background.YData;
x = eventdata.IntersectionPoint(1);
y = eventdata.IntersectionPoint(2);
amp = y - bg;
pnt(1) = addPoint(ax,x,y,false,handles.colors(length(handles.guesses)+1,:));
pnt(2) = addPoint(ax,x,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
pnt(3) = addPoint(ax,x,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
handles.guesses(end+1).gobs = pnt;
pnt(1).UserData.ind = length(handles.guesses);
pnt(1).UserData.desc = 1; % encode amplitude (also index to guesses)
pnt(2).UserData.ind = length(handles.guesses);
pnt(2).UserData.desc = 2; % encode right
pnt(3).UserData.ind = length(handles.guesses);
pnt(3).UserData.desc = 3; % encode left
ax.UserData = handles;
selected(pnt(1));
refit(hObj); % Force refit
end
