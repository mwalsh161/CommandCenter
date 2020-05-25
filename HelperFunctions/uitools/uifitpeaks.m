function varargout = uifitpeaks(ax,varargin)
%UIFITPEAKS Graphical/interactive version of fitpeaks
%   Takes all data in axes. User clicks to apply new guesses for peaks and
%   can modify existing guesses
%   Inputs (optional):
%       [Init]: Struct with initial peak guesses. Same format as FITPEAKS
%           returns for vals/init (each field must be same length). You can
%           choose to supply a scalar "background" field in addition.
%       [FitType]: "gauss", "lorentz", or "voigt" (default "guass")
%       [Bounds]: How tight to make bounds on fit; [lower,upper] = Bounds*initial guess
%       [StepSize]: Pixels to increment when moving guess with arrows
%       [InitWidth]: Pixel width to make newly clicked peaks
%       [ANY THING ELSE]: gets piped to fitpeaks for the init guess
%           (obviously this is simply ignored if Init is supplied)
%   Outputs:
%       pFit: line object corresponding to fitted line
%           UserData of this line is the cfit object
%           Deleting this line cleans up all uifitpeaks graphics and
%             listeners, restoring the original figure and axes callbacks
%
%   Interactivity:
%       Circles are rendered representing the degrees of freedom in the
%       fit. There is one at the peak that controls the location and
%       amplitude degrees of freedom. There are two at the FWHM positions
%       that control the width of the fit. Finally, there is one that
%       controls the background offset. Each peak will have its own color,
%       and the background will be black.
%       Arrow keys allow moving of the active circle in the axis returned
%       by gca. CTL+arrow allows for fine movement, and holding an arrow
%       allows for many movements prior to the next attempted fit.
%       If the fit returns a result that railed against an upper or lower
%       bound, the background will turn light red and the circle
%       corresponding to the offending degree of freedom will turn to a
%       square.
%       Double clicking will produce a new peak with InitWidth and an
%       amplitude+background of where you click.
%       You can delete a peak by using the delete key on any circle
%       corresponding to that peak.
%       [Shift+] Tab will change the selected point.

if isstruct(ax.UserData) && isfield(ax.UserData,[mfilename '_enabled'])
    warning('UIFITPEAKS already initialized on this axis');
    return % Already running on this axes
end
ax.UserData.([mfilename '_enabled']) = true;
persistent p
if isempty(p) % Avoid having to rebuild on each function call
    p = inputParser();
    p.KeepUnmatched = true;
    addParameter(p,'Init',[],@isstruct);
    addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz','voigt'})));
    addParameter(p,'Bounds',[0,2],@(x) isnumeric(x) && ismatrix(x) && length(x)==2);
    addParameter(p,'StepSize',10,@(x) isnumeric(x) && numel(x)==1);
    addParameter(p,'InitWidth',5,@(x) isnumeric(x) && numel(x)==1);
end
parse(p,varargin{:});
fittype = lower(p.Results.FitType);

try
x = [];
y = [];
children = [findobj(ax,'type','line') findobj(ax,'type','scatter')];
HitTestOff = gobjects(0);
for i = 1:length(children)
    if ~strcmp(get(children(i),'tag'),mfilename)
        x = [x; children(i).XData'];
        y = [y; children(i).YData'];
        % Need to set everything in the group's hittest to off
        target = children(i);
        while target.Parent ~= ax
            target = target.Parent;
        end
        HitTestOff = [HitTestOff;target;allchild(target)];
    end
end
set(HitTestOff,'HitTest','off');

bg = median(y);
if isempty(p.Results.Init)
    % Use fitpeaks (it is redundant to call fitpeaks again, but makes the
    % code flow in a more logical way)
    inputs = {};
    input_keys = fields(p.Unmatched);
    for i = 1:length(input_keys)
        inputs{end+1} = input_keys{i};
        inputs{end+1} = p.Unmatched.(input_keys{i});
    end
    [vals,~,~,~,init] = fitpeaks(x,y,'FitType',fittype,inputs{:});
    n = length(vals.locations); % vals tells us how many init points were used
    % Use init instead of vals because vals could fit an insane amplitude
    init.locations = init.locations(1:n);
    init.amplitudes = init.amplitudes(1:n);
    init.widths = init.widths(1:n);
else
    if isfield(p.Results.Init,'background') &&...
            isscalar(p.Results.Init.background) &&...
            isfinite(p.Results.Init.background)
        bg = p.Results.Init.background;
    end
    init = p.Results.Init;
    assert(isfield(init,'locations'),'"Init" requires a field locations.')
    assert(isfield(init,'widths'),'"Init" requires a field widths.')
    assert(isfield(init,'amplitudes'),'"Init" requires a field amplitudes.')
    assert(all(length(init.locations)==...
        [length(init.locations),length(init.widths),length(init.amplitudes)]),...
        'init.locations, init.amplitudes, and init.widths must all be the same length.');
end

% Prepare graphics
xfit = linspace(min(x),max(x),1001);
pFit = plot(ax,xfit,ones(size(xfit))*bg,'r','linewidth',1,'tag',mfilename);
pnt = addPoint(ax,(max(x)+min(x))/2,bg,false,[0 0 0]);
pnt.UserData.ind = NaN;
pnt.UserData.desc = 0; % desc=0 -> background

% Set up data structures
handles.([mfilename '_enabled']) = true; % Need to repeat because of how it is assigned later
handles.Bounds = p.Results.Bounds;
handles.StepSize = p.Results.StepSize;
handles.InitWid = p.Results.InitWidth;
handles.pFit = pFit;
handles.background = pnt;
handles.x = x;
handles.y = y;
handles.lock = false;
handles.active_point = [];
switch fittype
    case 'gauss'
        handles.fit_function = @gaussfit;
    case 'lorentz'
        handles.fit_function = @lorentzfit;
    case 'voigt'
        handles.fit_function = @voigtfit;
end
handles.guesses = struct('gobs',{});
handles.colors = lines;

% Go through adding newPeaks (note need to push handles to ax.UserData and
% pull them back after newPeak function calls
ax.UserData = handles;
for i = 1:length(init.locations) % vals tells us how many init points we took
    newPeak(ax,init.locations(i),bg+init.amplitudes(i),init.widths(i),bg);
end
handles = ax.UserData;

% Setup figure and axes callbacks
f = Base.getParentFigure(ax);
if isfield(f.UserData,[mfilename '_count'])
    f.UserData.([mfilename '_count']) = f.UserData.([mfilename '_count']) + 1;
else
    f.UserData.([mfilename '_count']) = 1;
end
handles.figure = f;
if f.UserData.([mfilename '_count']) == 1
    % Only remember if this is the first time called on a figure
    f.UserData.old_keypressfcn = get(f,'keypressfcn');
    f.UserData.old_keyreleasefcn = get(f,'keyreleasefcn');
    set(f,'keypressfcn',@keypressed);
    set(f,'keyreleasefcn',@refit);
end
handles.old_buttondownfcn = get(ax,'buttondownfcn');
set(ax,'buttondownfcn',@ax_clicked);
ax.UserData = handles;
ax.UserData.original_color = ax.Color;
addlistener(pFit,'ObjectBeingDestroyed',@clean_up);
% Init GUI state
selected(handles.background);
refit(ax);
if nargout
    varargout = {pFit};
end
catch err
    clean_up();
    rethrow(err);
end
end

function refit(ax,varargin)
if nargin == 0 || ~isa(ax,'matlab.graphics.axis.Axes')
    ax = gca;
end
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
handles.pFit.UserData = [];
init = struct('background',handles.background.YData,'amplitudes',NaN(0,1),'locations',NaN(0,1),'widths',NaN(0,1));
n = length(handles.guesses);
if n==0 % Edge case of no peaks
    handles.lock = false;
    ax.UserData = handles;
    set(ax,'Color',[1 1 1]);
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
if any(isnan(fitconfs(1:3*n)))
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
set(ax,'buttondownfcn',handles.old_buttondownfcn);
ax.Color = handles.original_color;
delete(findobj(ax,'tag',mfilename))
% Now, reset figure stuff
f = handles.figure;
f.UserData.([mfilename '_count']) = f.UserData.([mfilename '_count']) - 1;
if f.UserData.([mfilename '_count'])==0
    set(f,'keypressfcn',f.UserData.old_keypressfcn,...
                'keyreleasefcn',f.UserData.old_keyreleasefcn);
end
ax.UserData.([mfilename '_enabled']) = false;
end

function selected(hObj,~)
% Click callback for points generated by "addPoint"
ax = gca;
if ~isstruct(ax.UserData) || ~isfield(ax.UserData,[mfilename '_enabled'])
    return;
end
set(findobj(hObj.Parent,'tag',mfilename),'linewidth',1);
set(hObj,'linewidth',2);
ax.UserData.active_point = hObj;
end

function ax_clicked(hObj,eventdata)
% Click callback for axes
ax = gca;
if ax.UserData.lock
    return
end
handles = ax.UserData;
if ~strcmp(handles.figure.SelectionType,'open')
    return % Only use double click (i.e. "open")
end
bg = handles.background.YData;
x = eventdata.IntersectionPoint(1);
y = eventdata.IntersectionPoint(2);
wid = pixel2coord(ax,handles.InitWid,0);
newPeak(ax,x,y,wid,bg);
refit(ax); % Force refit
end

function keypressed(hObj,eventdata)
% If modified with control, [dx,dy] = [dx,dy]/10
ax = gca;
if ~isstruct(ax.UserData) || ~isfield(ax.UserData,[mfilename '_enabled']) || ax.UserData.lock
    return
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
    case 'tab'
        from_uifitpeaks = findobj(ax,'tag',mfilename);
        guess_gobs = gobjects(0);
        for i = 1:length(from_uifitpeaks)
            if isstruct(from_uifitpeaks(i).UserData) && isfield(from_uifitpeaks(i).UserData,'guess')
                guess_gobs(end+1) = from_uifitpeaks(i);
                if guess_gobs(end)==handles.active_point
                    cur_point_ind = length(guess_gobs);
                end
            end
        end
        if length(eventdata.Modifier)==1 && strcmp(eventdata.Modifier{1},'shift')
            next = mod(cur_point_ind,length(guess_gobs))+1;
        else
            next = mod(cur_point_ind-2,length(guess_gobs))+1;
        end
        selected(guess_gobs(next));
        return
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
    otherwise
        return
end
[dx,dy] = pixel2coord(ax,handles.StepSize,handles.StepSize); %[x, y]
if length(eventdata.Modifier)==1 && strcmp(eventdata.Modifier{1},'control')
    dx = dx/10;
    dy = dy/10;
end
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
% Adding a "guess" point (e.g. what is used for the initial fitting guess)
held = ishold(ax);
hold(ax,'on');
p = plot(ax,x,y,'color',color,'marker','o','linestyle','none',...
    'tag',mfilename,'linewidth',1,'UserData',struct('guess',true));
if railed
    p.Marker = 'square';
    p.Color = p.Color*0.7;
end
if ~held
    hold(ax,'off');
end
set(p,'buttondownfcn',@selected);
end

function newPeak(ax,x,y,wid,bg)
% Initialize to "not railed" in addPoint
handles = ax.UserData;
amp = y - bg;
pnt(1) = addPoint(ax,x,y,false,handles.colors(length(handles.guesses)+1,:));
pnt(2) = addPoint(ax,x-wid/2,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
pnt(3) = addPoint(ax,x+wid/2,bg+amp/2,false,handles.colors(length(handles.guesses)+1,:));
handles.guesses(end+1).gobs = pnt;
pnt(1).UserData.ind = length(handles.guesses);
pnt(1).UserData.desc = 1; % encode amplitude (also index to guesses)
pnt(2).UserData.ind = length(handles.guesses);
pnt(2).UserData.desc = 2; % encode right
pnt(3).UserData.ind = length(handles.guesses);
pnt(3).UserData.desc = 3; % encode left
ax.UserData = handles;
selected(pnt(1)); % Make the peak the newly selected point (where the click happened)
end
