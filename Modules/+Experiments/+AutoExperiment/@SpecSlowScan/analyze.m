function varargout = analyze(data)
%ANALYZE Examine data from all sites
%   Left/right arrows to go between sites (wraps around)

im = data.image.image;

fig = figure('name',mfilename,'numbertitle','off');
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
update(fig);

% Link UI control
fig.KeyPressFcn = @cycleSite;

if nargout
    varargout = {fig};
end
end

function selectSite(sc,eventdata)
if eventdata.Button == 1
    [~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[sc.XData; sc.YData]','K',1);
    [~,ind] = min(D);
    sc.UserData.fig.UserData.index = ind;
    update(sc.UserData.fig);
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
fig.UserData.index = mod(fig.UserData.index-1+direction,...
                         length(fig.UserData.sites))+1;
update(fig);
end

function update(fig)
if fig.UserData.busy
    warning('Chill! Busy fitting still...');
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

assert(isempty(site.experiments),'Missed some experiments!')
%uifitpeaks(ax(2));
%uifitpeaks(ax(3));
%uifitpeaks(ax(4));
catch err
end
fig.UserData.busy = false;
if exist('err','var')
    rethrow(err)
end
end