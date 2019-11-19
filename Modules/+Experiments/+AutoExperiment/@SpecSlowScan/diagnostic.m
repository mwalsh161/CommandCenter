function fig = diagnostic(data,analysis)
% This is not finished yet and far from working well or looking nice!
x = [];
y = [];
xx = [];
start = [];
stop = [];
set = [];
found = [];
% Piezo positions for set point and peak positions
setP = [];
peakP = [];
for ii = 1:size(analysis,1)
    xt = analysis(ii,1).locations;
    if length(xt) ~= 1
        continue
    end
    yt = analysis(ii,2).locations;
    n = length(yt);
    if n > 0 && ~any(isnan(yt))
        y = [y yt];
        x = [x zeros(1,n)+xt];
    end
    msk = strcmp({data.data.sites(ii).experiments.name},'Experiments.SlowScan.Open');
    I = find(msk,1,'last');
    for jj = I
        try
        start(end+1) = min(data.data.sites(ii).experiments(jj).data.data.freqs_measured);
        stop(end+1) = max(data.data.sites(ii).experiments(jj).data.data.freqs_measured);
        xx(end+1) = xt;
        found(end+1) = n;
        set(end+1) = data.data.sites(ii).experiments(jj).data.meta.prefs.freq_THz;
        catch
        end
    end
end

%% Refit
c = 299792;
fit_type = fittype('a/(x-b)+c');
options = fitoptions(fit_type);
options.Start = [c,0,0];

nm2THz = fit(x',y',fit_type,options);

%% Plot
fig = figure('name',mfilename,'numbertitle','off','Visible','off');
file_menu = findall(gcf,'tag','figMenuFile');
uimenu(file_menu,'Text','Export Data','callback',@export_data,'separator','on');

ax = axes('parent',fig);
sc = scatter(ax,x,y);
hold(ax,'on');
sc(2) = scatter(ax,xx(found>0),start(found>0),'g+');
sc(3) = scatter(ax,xx(found>0),stop(found>0),'r+');
sc(4) = scatter(ax,xx(found==0),start(found==0),'g*');
sc(5) = scatter(ax,xx(found==0),stop(found==0),'r*');
xlim = get(ax,'xlim');
xf = linspace(xlim(1),xlim(2),1000);
pfit = plot(ax,xf,data.meta.nm2THz(xf),'--k');
pfit(2) = plot(ax,xf,nm2THz(xf),'--m');
xlabel('Spectrum Wavelength (nm)');
ylabel('SlowScan.Open Frequency (THz)');
legend([sc pfit],{'Fitted Peaks','Open start % (with at least 1 peak)',...
    'open stop % (with at least 1 peak)', 'Open start % (with no peaks)',...
    'Open stop % (with no peaks)','Fit used in experiment','Fit from current data (File->export)'});

fig.Visible = 'on';

    function export_data(varargin)
        if ~isempty(nm2THz)
            var_name = 'nm2THz';
            i = 1;
            while evalin('base', sprintf('exist(''%s'',''var'') == 1',var_name))
                i = i + 1;
                var_name = sprintf('nm2THz%i',i);
            end
            if i > 1
                answer = questdlg(sprintf('Would you like to export "%s" data to workspace as new variable "%s" or overwrite existing "%s"?',...
                    'nm2THz',var_name,'nm2THz'),'Export','Overwrite','New Variable','No','Overwrite');
                if strcmp(answer,'Overwrite')
                    answer = 'Yes';
                    var_name = 'nm2THz';
                end
            else
                answer = questdlg(sprintf('Would you like to export "%s" data to workspace as new variable "%s"?','nm2THz',var_name),...
                    'Export','Yes','No','Yes');
            end
            if strcmp(answer,'Yes')
                assignin('base',var_name,nm2THz)
            end
        end
    end
end

