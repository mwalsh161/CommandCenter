function varargout = analyze(data)
%ANALYZE Examine data from all sites
%   See keyboard functionality for uifitpeaks
%   alt+Left/right arrows to go between sites (wraps around)
%   Will be prompted to export analysis data upon closing figure. This data
%   is stored in figure.UserData.AutoExperiment_analysis as follows:
%     N×3 struct array with fields: (N is number of sites, 3 corresponds to experiments)
%       amplitudes - Nx1 double
%       widths - Nx1 double
%       locations - Nx1 double
%       background - 1x1 double
%       fit - cfit object

im = data.image.image;

fig = figure('name',mfilename,'numbertitle','off','CloseRequestFcn',@closereq);
fig.Position(3) = fig.Position(3)*2;
ax = subplot(1,5,[1 2],'parent',fig);
hold(ax,'on');
imagesc(ax,im.ROI(1,:),im.ROI(2,:),im.image);
positions = reshape([data.sites.position],2,[]);
sc = scatter(positions(1,:),positions(2,:),'ButtonDownFcn',@selectSite);
sc.UserData.fig = fig;
p = scatter(NaN,NaN,'r+');
xlabel(ax,'X Position (um)');
ylabel(ax,'Y Position (um)');
colormap(fig,'gray');
axis(ax,'image');
set(ax,'ydir','normal');
hold(ax,'off');
ax(2) = subplot(1,5,3,'parent',fig); hold(ax(2),'on');
ax(3) = subplot(1,5,4,'parent',fig); hold(ax(3),'on');
ax(4) = subplot(1,5,5,'parent',fig); hold(ax(4),'on');
fig.UserData.index = 1;
fig.UserData.sites = data.sites;
fig.UserData.ax = ax;
fig.UserData.pos = p;
fig.UserData.busy = false;
fig.UserData.AutoExperiment_analysis = struct(...
            'fit',[],...
            'amplitudes',[],...
            'widths',[],...
            'locations',[],...
            'background',cell(length(data.sites),3));
update(fig); % Bypass changeSite since we have no previous site

% Link UI control
fig.KeyPressFcn = @cycleSite;

if nargout
    varargout = {fig};
end
end

function closereq(fig,~)
% Export data to workspace if analysis exists
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
end
delete(fig)
end

function changeSite(fig,new_index)
% Save the current analysis before moving to next site
save_state(fig);
fig.UserData.index = new_index;
update(fig);
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
if fig.UserData.busy
    warning('Chill! Busy still...');
    return
end
fig.UserData.busy = true;
try
site = fig.UserData.sites(fig.UserData.index);
ax = fig.UserData.ax;
colors = lines;
% Image
title(ax(1),sprintf('Site %i/%i',fig.UserData.index,length(fig.UserData.sites)));
set(fig.UserData.pos,'xdata',site.position(1),'ydata',site.position(2));

cla(ax(2)); cla(ax(3)); cla(ax(4));
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
attach_uifitpeaks(ax(2));
attach_uifitpeaks(ax(3));
attach_uifitpeaks(ax(4));
assert(isempty(site.experiments),'Missed some experiments!')
catch err
end
fig.UserData.busy = false;
if exist('err','var')
    rethrow(err)
end
end
%% UIfitpeaks adaptor
function save_state(fig)
dat = struct('background',cell(0,3),'locations',[],'amplitudes',[],'widths',[]);
ax = fig.UserData.ax;
for i = 2:4 % Go through each data axis
    fit_result = ax(i).UserData.pFit.UserData;
    fitcoeffs = coeffvalues(fit_result);
    n = (length(fitcoeffs)-1)/3; % 3 degrees of freedom per peak; subtract background
    dat(i-1).fit = fit_result;
    dat(i-1).background = fitcoeffs(1:n);
    dat(i-1).locations = fitcoeffs(n+1:2*n);
    dat(i-1).amplitudes = fitcoeffs(2*n+1:3*n);
    dat(i-1).widths = fitcoeffs(3*n+1);
end
fig.UserData.AutoExperiment_analysis(fig.UserData.index,:) = dat;
end
function attach_uifitpeaks(ax)
% Wrapper to attach uifitpeaks
% Let uifitpeaks update keyboard fcn, but then wrap that fcn again
uifitpeaks(ax);
f = ax.Parent;
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