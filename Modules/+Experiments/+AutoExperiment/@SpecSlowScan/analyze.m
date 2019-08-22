function varargout = analyze(data,varargin)
%ANALYZE Examine data from all sites
%   Inputs:
%       data: data produced by GetData method
%       [Analysis]: An analysis struct produced by this function
%       [FitType]: "gauss" or "lorentz" (default "gauss")
%       [inds]: array of indices to mask full dataset (default: all data)
%       [viewonly]: do not begin uifitpeaks on the axes
%   Outputs: None (see below)
%   Interactivity:
%       click on a spot to see corresponding data
%       [alt+] left/right arrows to change site index. The alt is only
%           necessary if viewonly=false, which is default.
%       Right clicking on axis will allow you to choose lorentz/gauss for that axis
%   Tag info for data:
%       Axes from left -> right:
%           'SpatialImageAx', 'SpectraAx', 'OpenLoopAx', 'ClosedLoopAx'
%       Image in 'SpatialImageAx': 'SpatialImage'; Scatter plot: 'sites'
%       All lines in 'SpectraAx': 'Spectra'
%       All errorfill children (line & patch) in 'OpenLoopAx': 'OpenLoop'
%       All errorfill children (line & patch) in 'ClosedLoopAx': 'ClosedLoop'
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
addParameter(p,'inds',1:length(data.data.sites),@(n)validateattributes(n,{'numeric'},{'vector'}));
addParameter(p,'viewonly',false,@islogical);
parse(p,varargin{:});

prefs = data.meta.prefs;
data = data.data;
im = data.image.image;
sites = data.sites(p.Results.inds);

fig = figure('name',mfilename,'numbertitle','off','CloseRequestFcn',@closereq);
fig.Position(3) = fig.Position(3)*2;
file_menu = findall(gcf,'tag','figMenuFile');
uimenu(file_menu,'Text','Export Analysis Data','callback',@export_data,'separator',true);
ax = subplot(1,5,[1 2],'parent',fig,'tag','SpatialImageAx');
hold(ax,'on');
imagesc(ax,im.ROI(1,:),im.ROI(2,:),im.image,'tag','SpatialImage');
positions = reshape([sites.position],length(data.sites(1).position),[]);
sc = scatter(positions(1,:),positions(2,:),'ButtonDownFcn',@selectSite,'tag','sites');
sc.UserData.fig = fig;
pos = scatter(NaN,NaN,'r+');
xlabel(ax,'X Position (um)');
ylabel(ax,'Y Position (um)');
colormap(fig,'gray');
axis(ax,'image');
set(ax,'ydir','normal');
hold(ax,'off');
ax(2) = subplot(1,5,3,'parent',fig,'tag','SpectraAx'); hold(ax(2),'on');
ax(3) = subplot(1,5,4,'parent',fig,'tag','OpenLoopAx'); hold(ax(3),'on');
ax(4) = subplot(1,5,5,'parent',fig,'tag','ClosedLoopAx'); hold(ax(4),'on');
% Constants and large structures go here
n = length(sites);
setappdata(fig,'viewonly',p.Results.viewonly);
setappdata(fig,'FitType',p.Results.FitType);
setappdata(fig,'wavenm_range',299792./prefs.freq_range); % Used when plotting
setappdata(fig,'inds',p.Results.inds);
setappdata(fig,'sites',sites);
setappdata(fig,'n',n);
setappdata(fig,'ax',ax);
setappdata(fig,'pos',pos);
if isstruct(p.Results.Analysis)
    setappdata(fig,'AutoExperiment_analysis',p.Results.Analysis);
else
    setappdata(fig,'AutoExperiment_analysis', struct(...
            'fit',cell(n,3),...
            'amplitudes',NaN,...
            'widths',NaN,...
            'locations',NaN,...
            'background',NaN,...
            'index',NaN)...
    );
end

% Frequently updated and small stuff here
fig.UserData.index = 1;
fig.UserData.busy = false;
fig.UserData.new_data = false;

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
AutoExperiment_analysis = getappdata(fig,'AutoExperiment_analysis');
if ~isempty(AutoExperiment_analysis)
    var_name = 'SpecSlowScan_analysis';
    i = 1;
    while evalin('base', sprintf('exist(''%s'',''var'') == 1',var_name))
        i = i + 1;
        var_name = sprintf('SpecSlowScan_analysis%i',i);
    end
    answer = questdlg(sprintf('Would you like to export analysis data to workspace as "%s"?',var_name),...
        'Export Analysis','Yes','No','Yes');
    if strcmp(answer,'Yes')
        assignin('base',var_name,AutoExperiment_analysis)
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
n = getappdata(fig,'n');
ind = mod(fig.UserData.index-1+direction,n)+1;
changeSite(fig,ind);
end

function update(fig)
persistent sites
if isempty(sites)
    sites = getappdata(fig,'sites');
end
ind = fig.UserData.index;
n = getappdata(fig,'n');
site = sites(ind);
ax = getappdata(fig,'ax');
nm_range = getappdata(fig,'wavenm_range');
pos = getappdata(fig,'pos');
AutoExperiment_analysis = getappdata(fig,'AutoExperiment_analysis');
% Image
ax(1).Title.String = sprintf('Site %i/%i',ind,n);
set(pos,'xdata',site.position(1),'ydata',site.position(2));

cla(ax(2),'reset'); cla(ax(3),'reset'); cla(ax(4),'reset');
hold(ax(2),'on'); hold(ax(3),'on'); hold(ax(4),'on');
titles = {'Spectrum'};
for i = find(strcmp('Experiments.Spectrum',{site.experiments.name}))
    experiment = site.experiments(i);
    if ~isempty(experiment.data)
        wavelength = experiment.data.wavelength;
        mask = and(wavelength>=min(nm_range),wavelength<=max(nm_range));
        plot(ax(2),wavelength(mask),experiment.data.intensity(mask),'tag','Spectra');
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('\\rm\\color{red}\\fontsize{8}%i\\Rightarrow%s',...
            i,strrep(strip(experiment.err.message),'\','\\')); % Escape backslash for tex interpreter
    end
end
ax(2).Title.String = titles;
ax(2).XLabel.String = 'Wavelength (nm)';
ax(2).YLabel.String = 'Intensity (a.u.)';

titles = {'Open Loop SlowScan'};
for i = find(strcmp('Experiments.SlowScan.Open',{site.experiments.name}))
    experiment = site.experiments(i);
    if ~isempty(experiment.data)
        errorfill(experiment.data.data.freqs_measured,...
                  experiment.data.data.sumCounts,...
                  experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                  'parent',ax(3),'tag','OpenLoop');
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('\\rm\\color{red}\\fontsize{8}%i\\Rightarrow%s',...
            i,strrep(strip(experiment.err.message),'\','\\')); % Escape backslash for tex interpreter
    end
end
ax(3).Title.String = titles;
ax(3).XLabel.String = 'Frequency (THz)';
ax(3).YLabel.String = 'Counts';

titles = {'Closed Loop SlowScan'};
for i = find(strcmp('Experiments.SlowScan.Closed',{site.experiments.name}))
    experiment = site.experiments(i);
    if ~isempty(experiment.data)
        errorfill(experiment.data.data.freqs_measured,...
                  experiment.data.data.sumCounts,...
                  experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                  'parent',ax(4),'tag','ClosedLoop');
    end
    if ~isempty(experiment.err)
        titles{end+1} = sprintf('\\rm\\color{red}\\fontsize{8}%i\\Rightarrow%s',...
            i,strrep(strip(experiment.err.message),'\','\\')); % Escape backslash for tex interpreter
    end
end
ax(4).Title.String = titles;
ax(4).XLabel.String = 'Frequency (THz)';
ax(4).YLabel.String = 'Counts';
if ~getappdata(fig,'viewonly')
    if ~isempty(findall(ax(2),'type','line'))
        attach_uifitpeaks(ax(2),AutoExperiment_analysis(ind,1),...
            'AmplitudeSensitivity',1);
    end
    if ~isempty(findall(ax(3),'type','line'))
        attach_uifitpeaks(ax(3),AutoExperiment_analysis(ind,2),...
            'AmplitudeSensitivity',1);
    end
    if ~isempty(findall(ax(4),'type','line'))
        attach_uifitpeaks(ax(4),AutoExperiment_analysis(ind,3),...
            'AmplitudeSensitivity',1);
    end
end
end
%% UIfitpeaks adaptor
function save_state(fig)
dat = struct('background',cell(0,3),'locations',[],'amplitudes',[],'widths',[]);
ax = getappdata(fig,'ax');
FitType = getappdata(fig,'FitType');
inds = getappdata(fig,'inds');
index = fig.UserData.index;
AutoExperiment_analysis = getappdata(fig,'AutoExperiment_analysis');
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
        if strcmpi(FitType,'gauss')
            dat(i-1).widths = dat(i-1).widths*2*sqrt(2*log(2));
        end
        dat(i-1).index = inds(index);
    else
        dat(i-1).fit = [];
        dat(i-1).amplitudes = [];
        dat(i-1).locations = [];
        dat(i-1).widths = [];
        dat(i-1).background = [];
        dat(i-1).index = [];
    end
end
if ~isempty(dat)
    AutoExperiment_analysis(index,:) = dat;
    setappdata(fig,'AutoExperiment_analysis',AutoExperiment_analysis);
    fig.UserData.new_data = true;
end
end
function attach_uifitpeaks(ax,init,varargin)
% Wrapper to attach uifitpeaks
% Let uifitpeaks update keyboard fcn, but then wrap that fcn again
fig = ax.Parent;
FitType = getappdata(fig,'FitType');
if any(isnan(init.locations))
    uifitpeaks(ax,'fittype',FitType,varargin{:});
else
    uifitpeaks(ax,'fittype',FitType,'init',init,varargin{:});
end
if fig.UserData.uifitpeaks_count == 1 % Only set on first creation
    fig.UserData.uifitpeaks_keypress_callback = get(fig,'keypressfcn');
    set(fig,'keypressfcn',@keypress_wrapper);
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