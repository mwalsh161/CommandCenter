function varargout = uifitpeaks(ax,varargin)
%UIFITPEAKS Graphical/interactive version of fitpeaks
%   Takes all data in axes. User clicks to apply new guesses for peaks and
%   can modify existing guesses
%   Inputs (optional):
%       [FitType]: "gauss" or "lorentz" (default "guass")
%   Outputs:
%       pFit: line object corresponding to fitted line
%           UserData of this line is the cfit object
%           Deleting this line cleans up all uifitpeaks graphics and
%             listeners, restoring the original figure and axes callbacks

p = inputParser;
addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz'})));
parse(p,varargin{:});
fittype = lower(p.Results.FitType);

% Init with fitpeaks
x = [];
y = [];
children = [findall(ax,'type','line') findall(ax,'type','scatter')];
for i = 1:length(children)
    if ~strcmp(get(children(i),'tag'),mfilename)
        x = [x; children(i).XData'];
        y = [y; children(i).YData'];
    end
end

colors = lines;
xfit = linspace(min(x),max(x),1001);
[vals,confs,fits,~,init] = fitpeaks(x,y,'FitType',fittype,'noisemodel','shot');
bg = fits{end}.d; % Background
held = ishold(ax);
hold(ax,'on');
pFit = plot(ax,xfit,fits{end}(xfit),'r','linewidth',1,'tag',mfilename);
pFit.UserData = fits{end};

if ~held
    hold(ax,'off');
end
handles.ax = ax;
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
handles.figure = f;
handles.old_keypressfcn = get(f,'keypressfcn');
handles.old_buttondownfcn = get(ax,'buttondownfcn');
guidata(ax,handles);
set(f,'keypressfcn',@shifted);
set(ax,'buttondownfcn',@newPeak);
addlistener(pFit,'ObjectBeingDestroyed',@clean_up);
if nargout
    varargout = {pFit};
end
end

function clean_up(hObj,~)
handles = guidata(hObj);
set(handles.figure,'keypressfcn',handles.old_keypressfcn);
set(handles.ax,'buttondownfcn',handles.old_buttondownfcn);
delete(findall(handles.ax,'tag',mfilename))
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
handles = guidata(hObj);
if handles.lock
    return
end
bg = handles.background.YData;
x = eventdata.IntersectionPoint(1);
y = eventdata.IntersectionPoint(2);
amp = y - bg;
pnt(1) = addPoint(handles.ax,x,y,false,handles.colors(length(handles.guesses)+1,:));
pnt(2) = addPoint(handles.ax,x,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
pnt(3) = addPoint(handles.ax,x,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
handles.guesses(end+1).gobs = pnt;
pnt(1).UserData.ind = length(handles.guesses);
pnt(1).UserData.desc = 1; % encode amplitude (also index to guesses)
pnt(2).UserData.ind = length(handles.guesses);
pnt(2).UserData.desc = 2; % encode right
pnt(3).UserData.ind = length(handles.guesses);
pnt(3).UserData.desc = 3; % encode left
guidata(hObj,handles);
selected(pnt(1));
refit(hObj);
end

function selected(hObj,~)
set(findall(hObj.Parent,'tag',mfilename),'linewidth',1);
set(hObj,'linewidth',2);
handles = guidata(hObj);
handles.active_point = hObj;
guidata(hObj,handles);
end

function shifted(hObj,eventdata)
d = 0.01;
handles = guidata(hObj);
if handles.lock
    return
end
if handles.lock
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
end
if ismember(eventdata.Key,{'leftarrow','rightarrow'})
    if any(handles.active_point.UserData.desc==[0,1,2,3])
        modified = true;
        xlim = get(handles.ax,'xlim');
        dx = diff(xlim)*d*dir;
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
        ylim = get(handles.ax,'ylim');
        dy = diff(ylim)*d*dir;
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
    guidata(hObj,handles);
    refit(hObj);
end
end

function refit(hObj)
limit = [0, 1.2];
handles = guidata(hObj);
handles.lock = true;
guidata(hObj,handles);
try
handles.pFit.YData = NaN(size(handles.pFit.XData));
init = struct('background',handles.background.YData,'amplitudes',NaN(0,1),'locations',NaN(0,1),'widths',NaN(0,1));
n = length(handles.guesses);
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
    set(handles.ax,'Color',[1 0.8 0.8]);
else
    set(handles.ax,'Color',[1 1 1]);
end
catch err
end
handles.lock = false;
guidata(hObj,handles);
if exist('err','var')
    rethrow(err);
end
end