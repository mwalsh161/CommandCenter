function varargout = analyze(data,varargin)
%ANALYZE Examine data from all sites
%   Inputs:
%       data: data produced by GetData method
%       [Analysis]: An analysis struct produced by this function
%       [FitType]: "gauss" or "lorentz" (default "gauss")
%       [viewonly]: do not begin uifitpeaks on the axes
%   Outputs: None (see below)
%   Interactivity:
%       click on a spot to see corresponding data
%       [alt+] left/right arrows to change site index. The alt is only
%           necessary if viewonly=false, which is default.
%       Right clicking on axis will allow you to choose lorentz/gauss for that axis
%   When viewonly = false, main keyboard functionality goes to UIFITPEAKS
%       Click on circle node to select it, use arrows to change its
%       location (and corresponding guess value).
%       ctl+arrows allow fine control.
%       [Shift+] Tab changes selected point
%   Analysis data is stored in figure.UserData.AutoExperiment_analysis as follows:
%     N×3 struct array with fields: (N is number of sites, 3 corresponds to experiments)
%       amplitudes - Nx1 double
%       widths - Nx1 double (all FWHM)
%       locations - Nx1 double
%       background - 1x1 double
%       fit - cfit object
%   Can export from file menu
%   Will be prompted to export analysis data to base workspace upon closing
%   figure if no export since last analysis data update (NOTE this is only
%   saved when switching sites).
%       This will not overwrite previously exported data sets.

p = inputParser();
addParameter(p,'Analysis',[],@isstruct);
addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'viewonly',false,@islogical);
parse(p,varargin{:});

im = data.image.image;

fig = figure('name',mfilename,'numbertitle','off','CloseRequestFcn',@closereq);
fig.Position(3) = fig.Position(3)*2;
file_menu = findall(gcf,'tag','figMenuFile');
uimenu(file_menu,'Text','Export Analysis Data','callback',@export_data,'separator',true);
ax = subplot(1,5,[1 2],'parent',fig);
hold(ax,'on');
imagesc(ax,im.ROI(1,:),im.ROI(2,:),im.image);
positions = reshape([data.sites.position],2,[]);
sc = scatter(positions(1,:),positions(2,:),'ButtonDownFcn',@selectSite);
sc.UserData.fig = fig;
pos = scatter(NaN,NaN,'r+');
xlabel(ax,'X Position (um)');
ylabel(ax,'Y Position (um)');
colormap(fig,'gray');
axis(ax,'image');
set(ax,'ydir','normal');
hold(ax,'off');
ax(2) = subplot(1,5,3,'parent',fig); hold(ax(2),'on');
ax(3) = subplot(1,5,4,'parent',fig); hold(ax(3),'on');
ax(4) = subplot(1,5,5,'parent',fig); hold(ax(4),'on');
fig.UserData.new_data = false;
fig.UserData.viewonly = p.Results.viewonly;
fig.UserData.FitType = p.Results.FitType;
fig.UserData.index = 1;
fig.UserData.sites = data.sites;
fig.UserData.ax = ax;
fig.UserData.pos = pos;
fig.UserData.busy = false;
if isstruct(p.Results.Analysis)
    fig.UserData.AutoExperiment_analysis = p.Results.Analysis;
else
    fig.UserData.AutoExperiment_analysis = struct(...
            'fit',[],...
            'amplitudes',[],...
            'widths',[],...
            'locations',[],...
            'background',cell(length(data.sites),3));
end
% Link UI control
fig.KeyPressFcn = @cycleSite;
update(fig); % Bypass changeSite since we have no previous site

if nargout
    varargout = {fig};
end
end

function export_data(fig,varargin)
if nargin < 1 || ~isa(fig,'matlab.ui.Figure')
    [~,fig] = gcbo;
end
save_state(fig);
if isfield(fig.UserData,'AutoExperiment_analysis') && ~isempty(fig.UserData.AutoExperiment_analysis)
    var_name = 'SpecSlowScan_analysis';
    i = 1;
    while evalin('base', sprintf('exist(''%s'',''var'') == 1',var_name))
        i = i + 1;
        var_name = sprintf('SpecSlowScan_analysis%i',i);
    end
    answer = questdlg(sprintf('Would you like to export analysis data to workspace as "%s"?',var_name),...
        mfilename,'Yes','No','Yes');
    if strcmp(answer,'Yes')
        assignin('base',var_name,fig.UserData.AutoExperiment_analysis)
    end
    fig.UserData.new_data = false;
end
end

function closereq(fig,~)
% Export data to workspace if analysis exists
try
    if fig.UserData.new_data
        export_data(fig);
    end
catch err
    delete(fig)
    rethrow(err);
end
delete(fig)
end

function changeSite(fig,new_index)
if fig.UserData.busy
    warning('Chill! Busy still...');
    return
end
fig.UserData.busy = true;
% Save the current analysis before moving to next site
save_state(fig);
fig.UserData.index = new_index;
try
    update(fig);
catch err
    fig.UserData.busy = false;
    rethrow(err)
end
fig.UserData.busy = false;
end

function selectSite(sc,eventdata)
if eventdata.Button == 1
    [~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[sc.XData; sc.YData]','K',1);
    [~,ind] = min(D);
    changeSite(sc.UserData.fig,ind);
end
end

function cycleSite(fig,eventdata)
switch eventdata.Key
    case 'leftarrow'
        direction = -1;
    case 'rightarrow'
        direction = 1;
    otherwise % Ignore anything else
        return
end
ind = mod(fig.UserData.index-1+direction,length(fig.UserData.sites))+1;
changeSite(fig,ind);
end

function update(fig)
site = fig.UserData.sites(fig.UserData.index);
ax = fig.UserData.ax;
colors = lines;
% Image
title(ax(1),sprintf('Site %i/%i',fig.UserData.index,length(fig.UserData.sites)));
set(fig.UserData.pos,'xdata',site.position(1),'ydata',site.position(2));

cla(ax(2),'reset'); cla(ax(3),'reset'); cla(ax(4),'reset');
hold(ax(2),'on'); hold(ax(3),'on'); hold(ax(4),'on');
titles = {'Spectrum'};
for i = 1:length(site.experiments)
    experiment = site.experiments(1);
    if ~strcmp(experiment.name,'Experiments.Spectrum')
        break
    end
    site.experiments(1) = [];
    if ~isempty(experiment.data)
        plot(ax(2),experiment.data.wavelength,...
                  experiment.data.intensity,'color',colors(i,:));
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('%i: %s',i,experiment.err.message);
    end
end
title(ax(2),strjoin(titles,newline),'interpreter','none');
xlabel(ax(2),'Wavelength (nm)');
ylabel(ax(2),'Intensity (a.u.)');

titles = {'Open Loop SlowScan'};
for i = 1:length(site.experiments)
    experiment = site.experiments(1);
    if ~strcmp(experiment.name,'Experiments.SlowScan.Open')
        break
    end
    site.experiments(1) = [];
    if ~isempty(experiment.data)
        errorfill(experiment.data.data.freqs_measured,...
                  experiment.data.data.sumCounts,...
                  experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                  'parent',ax(3));
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('%i: %s',i,experiment.err.message);
    end
end
title(ax(3),strjoin(titles,newline),'interpreter','none');
xlabel(ax(3),'Frequency (THz)');
ylabel(ax(3),'Counts');

titles = {'Closed Loop SlowScan'};
for i = 1:length(site.experiments)
    experiment = site.experiments(1);
    if ~strcmp(experiment.name,'Experiments.SlowScan.Closed')
        break
    end
    site.experiments(1) = [];
    if ~isempty(experiment.data)
        errorfill(experiment.data.data.freqs_measured,...
                  experiment.data.data.sumCounts,...
                  experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                  'parent',ax(4));
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('%i: %s',i,experiment.err.message);
    end
end
title(ax(4),strjoin(titles,newline),'interpreter','none');
xlabel(ax(4),'Frequency (THz)');
ylabel(ax(4),'Counts');
if ~fig.UserData.viewonly
    if ~isempty(findall(ax(2),'type','line'))
        attach_uifitpeaks(ax(2),...
            fig.UserData.AutoExperiment_analysis(fig.UserData.index,1));
    end
    if ~isempty(findall(ax(3),'type','line'))
        attach_uifitpeaks(ax(3),...
            fig.UserData.AutoExperiment_analysis(fig.UserData.index,2),...
            'noisemodel','shot');
    end
    if ~isempty(findall(ax(4),'type','line'))
        attach_uifitpeaks(ax(4),...
            fig.UserData.AutoExperiment_analysis(fig.UserData.index,3),...
            'noisemodel','shot');
    end
end
assert(isempty(site.experiments),'Missed some experiments!')
end
%% UIfitpeaks adaptor
function save_state(fig)
dat = struct('background',cell(0,3),'locations',[],'amplitudes',[],'widths',[]);
ax = fig.UserData.ax;
for i = 2:4 % Go through each data axis
    if ~isstruct(ax(i).UserData) || ~isfield(ax(i).UserData,'uifitpeaks_enabled')
        continue
    end
    fit_result = ax(i).UserData.pFit.UserData;
    if ~isempty(fit_result)
        fitcoeffs = coeffvalues(fit_result);
        n = (length(fitcoeffs)-1)/3; % 3 degrees of freedom per peak; subtract background
        dat(i-1).fit = fit_result;
        dat(i-1).amplitudes = fitcoeffs(1:n);
        dat(i-1).locations = fitcoeffs(n+1:2*n);
        dat(i-1).widths = fitcoeffs(2*n+1:3*n);
        dat(i-1).background = fitcoeffs(3*n+1);
        if strcmpi(fig.UserData.FitType,'gauss')
            dat(i-1).widths = dat(i-1).widths*2*sqrt(2*log(2));
        end
    else  % Changing [] -> NaN shows that it has been processed
        dat(i-1).fit = [];
        dat(i-1).locations = NaN;
        dat(i-1).background = NaN;
        dat(i-1).amplitudes = NaN;
        dat(i-1).widths = NaN;
    end
end
if ~isempty(dat)
    fig.UserData.AutoExperiment_analysis(fig.UserData.index,:) = dat;
    fig.UserData.new_data = true;
end
end
function attach_uifitpeaks(ax,init,varargin)
% Wrapper to attach uifitpeaks
% Let uifitpeaks update keyboard fcn, but then wrap that fcn again
f = ax.Parent;
if isempty(init.locations) || any(isnan(init.locations))
    uifitpeaks(ax,'fittype',f.UserData.FitType,varargin{:});
else
    uifitpeaks(ax,'fittype',f.UserData.FitType,'init',init,varargin{:});
end
if f.UserData.uifitpeaks_count == 1 % Only set on first creation
    f.UserData.uifitpeaks_keypress_callback = get(f,'keypressfcn');
    set(f,'keypressfcn',@keypress_wrapper);
end
end
function keypress_wrapper(hObj,eventdata)
% uifitpeaks doesn't use alt, so we will distinguish with that
if length(eventdata.Modifier)==1 && strcmp(eventdata.Modifier{1},'alt')
    cycleSite(hObj,eventdata);
else
    hObj.UserData.uifitpeaks_keypress_callback(hObj,eventdata);
end
end