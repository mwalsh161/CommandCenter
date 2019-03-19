function varargout = view(varargin)
%VIEW Builds simple figure viewer with plot of all data taken for each NV
%   view()           Open a file finder to select file
%   view(fname)      Load and analyze supplied filename; if aborted returns empty results
%   view(slowscan)   Analyze slowscan struct (the root should be the "data" var saved by CommandCenter)
%   view(parent,__)  Use the parent fig-like object instead of making new
%
%   Generate figure with the scan on top and an NV's data structure plotted
%   below. Navigate NVs using arrow keys or the bottom left dropdown menu.
%
%   Returns via varargout upon success the slowscan data struct and parent
%% Get inputs
slowscan = [];
new_parent = false;
if nargin > 0 && contains(class(varargin{1}),'matlab.ui')
    parent = varargin{1};
    varargin(1) = [];
else
    height = 640;
    width = 438;
    parent = figure('visible','off');
    parent.Position(1) = parent.Position(1) - (width - parent.Position(3))/2;
    parent.Position(3) = width;
    parent.Position(2) = parent.Position(2) - (height - parent.Position(4));
    parent.Position(4) = height;
    new_parent = true;
end
if ~isempty(varargin)
    switch class(varargin{1})        
        case 'char'
            slowscan = load(varargin{1});
            slowscan = slowscan.data;
        case 'struct'
            slowscan = varargin{1};
    end
else
    % Need to let user find file
    [file,path] = uigetfile('*.mat','Select SlowScan File');
    if ~file % Abort
        varargout = cell(1,nargout);
        return
    end
    slowscan = load(fullfile(path,file));
    slowscan = slowscan.data;
end
%% Main
try
    parent.UserData.NVnum = 1;
    if isfield(slowscan.data,'scan') % 'v1'
        PLscan = slowscan.data.scan.image;
        parent.UserData.NVs = slowscan.data.scan.NV;
    else % 'v2'
        PLscan = slowscan.data.image;
        parent.UserData.NVs = slowscan.data.NV;
    end
    ax = subplot(4,1,[1 2],'parent',parent);
    imagesc(ax,PLscan.ROI(1,:),PLscan.ROI(2,:),PLscan.image);
    if isfield(slowscan,'notes') % Backwards compatibility
        xlabel(ax,slowscan.notes);
    end
    title(ax,sprintf('%i ms integration',PLscan.ModuleInfo.dwell));
    axis(ax,'image'); colormap(ax,'gray'); set(ax,'ydir','normal'); hold(ax,'on'); colorbar(ax);
    pLoc = plot(NaN,NaN,'r+');
    parent.UserData.pLoc = pLoc;
    % Update for first NV
    updatePlot(parent)
    NVlist = cellfun(@(a)sprintf('NV %i',a),num2cell(1:length(parent.UserData.NVs)),'uniformoutput',false);
    uicontrol('style','popupmenu','string',NVlist,'callback',@newNV,'tag','NVnavigate');
    set(Base.getParentFigure(parent),'keypressfcn',@(~,eventdata)advance(parent,eventdata))
catch err
    if new_parent
        delete(parent);
    end
    rethrow(err);
end
% Make visible
parent.Visible = 'on';
varargout = {slowscan,parent};
varargout = varargout(1:nargout);
end

function advance(parent,eventdata)
% Advance with left/right arrows by updating the popupmenu, and forcing
% callback
switch eventdata.Key
    case 'rightarrow'
        dir = 1;
    case 'leftarrow'
        dir = -1;
    otherwise
        return
end
currentNV = parent.UserData.NVnum;
nextNV = max(min(length(parent.UserData.NVs),currentNV+dir),1);
h = findall(parent,'tag','NVnavigate');
h.Value = nextNV;
newNV(h)
end

function newNV(hObj,~)
% Grab number out of string, update the parent object and force updatePlot
newNV = hObj.String{hObj.Value};
NVnum = split(newNV);
NVnum = str2double(NVnum{2});
hObj.Parent.UserData.NVnum = NVnum;
updatePlot(hObj.Parent);
end

function updatePlot(parent)
% Use parent UserData to regenerate entire axes
fit_shade = 0.5;
colors = lines;
NV = parent.UserData.NVs(parent.UserData.NVnum);
parent.UserData.pLoc.XData = NV.loc(1);
parent.UserData.pLoc.YData = NV.loc(2);

ax = subplot(4,1,3,'parent',parent);
cla(ax(1),'reset'); hold(ax(1),'on');
ax(2) = subplot(4,1,4,'parent',parent);
cla(ax(2),'reset'); hold(ax(2),'on');
nPlot = 1;
plot(ax(1),NV.spec.spectrum.x,NV.spec.spectrum.y);
for i = 1:length(NV.spec.specloc)
    plot(ax(1),[1 1]*NV.spec.specloc(i),get(ax(1),'ylim'),'k--');
end
set(ax(1),'xlim',[635,640]);
for i = 1:length(NV.survey)
    survey = NV.survey(i);
    p = plot(ax(2),survey.freqs,survey.counts,'color',colors(nPlot,:));
    if ~isempty(survey.ScanFit.fit)
        xFit = linspace(survey.freqs(1),survey.freqs(end),1000);
        plot(ax(2),xFit,survey.ScanFit.fit(xFit),'color',p.Color*fit_shade);
    end
    nPlot = mod(nPlot,size(colors,1))+1; % Silly indexing from 1
end
for i = 1:length(NV.region)
    for j = 1:length(NV.region(i).slow)
        scan = NV.region(i).slow(j);
        p = plot(ax(2),scan.freqs,scan.counts,'color',colors(nPlot,:));
        if ~isempty(scan.ScanFit.fit)
            xFit = linspace(scan.freqs(1),scan.freqs(end),1000);
            plot(ax(2),xFit,scan.ScanFit.fit(xFit),'color',p.Color*fit_shade);
        end
        nPlot = mod(nPlot,size(colors,1))+1; % Silly indexing from 1
    end
end
xlabel(ax(1),'Wavelength (nm)'); ylabel(ax(1),'Intensity');
xlabel(ax(2),sprintf('Frequency (THz)\n%s',NV.status)); ylabel(ax(2),'Counts');
title(ax(1),sprintf('NV %i',parent.UserData.NVnum));
drawnow;
end