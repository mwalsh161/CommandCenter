function fig = diagnostic(data,analysis)
% Per-peak data
n = sum(~isnan([analysis(:,2).widths]));
percents = zeros(n,1);  % Second dim is for worse metrics
freqs.open = NaN(1,n); % Open loop/PLE (THz)
freqs.spec = NaN(1,n); % Spectrum/PL (nm)

% Per experiment data
% Optimistic start/stop points (e.g. start is min of experiment set)
PL_location = [];
starts = [];
stops = [];
n_peaks_found = [];
median_open_spacing = []; % per "pixel"

peak_counter = 1; % For per-peak data index
site_counter = 1;
for ii = 1:size(analysis,1)
    PL_locs = analysis(ii,1).locations;
    if length(PL_locs) < 1
        continue
    end
    PL_locs_THz = data.meta.nm2THz(PL_locs);
    % Get completed/not skipped open scans
    msk = strcmp({data.data.sites(ii).experiments.name},'Experiments.SlowScan.Open') & ...
            [data.data.sites(ii).experiments.completed] & ~[data.data.sites(ii).experiments.skipped];
    exp_inds = find(msk);
    PLE_locs = analysis(ii,2).locations;
    n_peaks = length(PLE_locs);
    for jj = 1:n_peaks
        if ~isnan(PLE_locs(jj))
            % Add to per-peak data while being careful if multiple PL_locs
            [~,PL_locs_ind] = min(abs(PLE_locs(jj)-PL_locs_THz));
            freqs.spec(peak_counter) = PL_locs(PL_locs_ind);
            freqs.open(peak_counter) = PLE_locs(jj);
            % Keep most optimistic percent value
            best = NaN(length(exp_inds),2); % [percent, metric] where metric is how close it is to mid point relative to range
            for kk = 1:length(exp_inds)
                exp = data.data.sites(ii).experiments(exp_inds(kk));
                percent_vals = exp.data.meta.vars.vals;
                percent_lim = [min(percent_vals), max(percent_vals)];
                [~,I] = min(abs(exp.data.data.freqs_measured - PLE_locs(jj)));
                metric = abs(mean(percent_lim) - percent_vals(I))/diff(percent_lim);
                best(kk,:) = [percent_vals(I), metric];
            end
            assert(~isempty(best),'Have an open PLE location but failed to find open slow scan experiment!');
            [~,I] = sort(best(:,2));
            percents(peak_counter,1:length(I)) = best(I,1);
            peak_counter = peak_counter + 1;
        end
    end
    % Per experiment data
    if any(msk)
        start = Inf;
        stop = -Inf;
        spacing_vals = [];
        for kk = find(msk)
            try
            exp = data.data.sites(ii).experiments(kk);
            if min(exp.data.data.freqs_measured) < start
                start = min(exp.data.data.freqs_measured);
            end
            if max(exp.data.data.freqs_measured) > stop
                stop = max(exp.data.data.freqs_measured);
            end
            catch
            end
            spacing_vals = [spacing_vals median(diff(sort(exp.data.data.freqs_measured)))];
        end
        assert(isfinite(start)&&isfinite(stop), 'Start/stop must be finite!');
        starts(site_counter) = start;
        stops(site_counter) = stop;
        n_peaks_found(site_counter) = n_peaks;
        median_open_spacing(site_counter) = median(spacing_vals);
        % Again, choose closest
        [~,I] = min(abs(mean([start stop]) - PL_locs_THz));
        PL_location(site_counter) = PL_locs(I);
        site_counter = site_counter + 1;
    end
end
percents(percents==0) = NaN;

%% Refit
c = 299792;
fit_type = fittype('a/(x-b)+c');
options = fitoptions(fit_type);
options.Start = [c,0,0];

nm2THz = fit(freqs.open',freqs.spec',fit_type,options);

%% Plot
fig = UseFigure(mfilename,'name',mfilename,'numbertitle','off','Visible','off',true);
file_menu = findobj(fig,'tag','figMenuFile');
if ~isempty(file_menu)
    uimenu(file_menu,'Text','Export Data','callback',@export_data,'separator','on');
end

ax = subplot(1,3,1,'parent',fig);
ax(2) = subplot(1,3,2,'parent',fig);
ax(3) = subplot(1,3,3,'parent',fig);
sc = scatter(ax(1),freqs.spec,freqs.open);
hold(ax(1),'on');
more_than_one = n_peaks_found>0;
none_found = n_peaks_found==0;
sc(2) = scatter(ax(1),PL_location(more_than_one),starts(more_than_one),'g+');
sc(3) = scatter(ax(1),PL_location(more_than_one),stops(more_than_one),'r+');
sc(4) = scatter(ax(1),PL_location(none_found),starts(none_found),'g*');
sc(5) = scatter(ax(1),PL_location(none_found),stops(none_found),'r*');
xlim = get(ax(1),'xlim');
xf = linspace(xlim(1),xlim(2),1000);
pfit = plot(ax(1),xf,data.meta.nm2THz(xf),'--k');
pfit(2) = plot(ax(1),xf,nm2THz(xf),'--m');
xlabel(ax(1),'Spectrum Wavelength (nm)');
ylabel(ax(1),'SlowScan.Open Frequency (THz)');
legend([sc pfit],{'Fitted Peaks','Open start % (with at least 1 peak)',...
    'open stop % (with at least 1 peak)', 'Open start % (with no peaks)',...
    'Open stop % (with no peaks)','Fit used in experiment','Fit from current data (File->export)'});

histogram(ax(2),percents(:,1));
set(ax(2),'xlim',[0, 100])
xlabel(ax(2),'Percentage of Peak (%)')

histogram(ax(3),[analysis(:,2).widths]*1000*1000); hold(ax(3),'on');
histogram(ax(3),[analysis(:,3).widths]*1000*1000);
plot(ax(3),[0 0]+median(median_open_spacing)*1000*1000,get(ax(3),'ylim'),'--k');
legend(ax(3),{'Open (coarse)','Closed','Median Step Size in Open'})
xlabel(ax(3),'Peak Widths (MHz)')

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

