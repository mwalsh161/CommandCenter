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
%       [alt+] left/right arrows to change site site_index. The alt is only
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
%   Analysis data is stored in figure.UserData.analysis as follows:
%     N×3 struct array with fields: (N is number of sites, 3 corresponds to experiments)
%       amplitudes - Nx1 double
%       widths - Nx1 double (all FWHM)
%       locations - Nx1 double
%       background - 1x1 double
%       fit - cfit object or empty if no peaks found
%       index - index into data.sites. If NaN, this wasn't analyzed
%   Can export from file menu
%   Will be prompted to export analysis data to base workspace upon closing
%   figure if no export since last analysis data update_all (NOTE this is only
%   saved when switching sites).
%       This will not overwrite previously exported data sets unless
%       specified.
%
%   *NOTE*: sites is also (optionally) exported. If you loaded this from a
%   file, you will need to re-insert the sites field in at the right spot!!
%       Can be useful for updating the redo_requested flag

p = inputParser();
addParameter(p,'Analysis',[],@isstruct);
addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'inds',1:length(data.data.sites),@(n)validateattributes(n,{'numeric'},{'vector'}));
addParameter(p,'viewonly',false,@islogical);
parse(p,varargin{:});

prefs = data.meta.prefs;
FullData = data;
data = FullData.data;
im = data.image.image;
sites = data.sites(p.Results.inds);

fig = figure('name',mfilename,'numbertitle','off','CloseRequestFcn',@closereq);
fig.Position(3) = fig.Position(3)*2;
file_menu = findall(gcf,'tag','figMenuFile');
uimenu(file_menu,'Text','Go to Index','callback',@go_to,'separator','on');
uimenu(file_menu,'Text','Export Data','callback',@export_data);
uimenu(file_menu,'Text','Diagnostic Plot','callback',@open_diagnostic);
bg(1) = uipanel(fig,'units','normalized','position',[0   0 1/4 1],'BorderType','none');
bg(2) = uipanel(fig,'units','normalized','position',[1/4 0 3/4 1],'BorderType','none');
splitPan(1) = Base.SplitPanel(bg(1),bg(2),'horizontal');
set(splitPan(1).dividerH,'BorderType','etchedin')
inner(1) = uipanel(bg(2),'units','normalized','position',[0 1/4 1 3/4],'BorderType','none');
inner(2) = uipanel(bg(2),'units','normalized','position',[0 0   1 1/4],'BorderType','none');
splitPan(2) = Base.SplitPanel(inner(1),inner(2),'vertical');
set(splitPan(2).dividerH,'BorderType','etchedin')
for i_ax = 1:3
    pan_ax(i_ax) = uipanel(inner(1),'units','normalized','position',[(i_ax-1)/3 0 1/3 1],'BorderType','none');
    selector(i_ax) = uitable(inner(2),'ColumnName',{'','',  'i',  'Datetime','Age','Redo','Duration','Skipped','Completed','Error'},...
                                  'ColumnEditable',[true,false,false,false,     false,true,  false,     false,    false,      false],...
                                  'ColumnWidth',   {15,15,   20,   120,       25,   35,    50,        50,       70,         40},...
                                  'units','normalized','Position',[(i_ax-1)/3 0 1/3 1],...
                                  'CellEditCallback',@selector_edit_callback);
    selector(i_ax).UserData = i_ax;
end

ax = axes('parent',bg(1),'tag','SpatialImageAx');
hold(ax,'on');
if ~isempty(im)
    imagesc(ax,im.ROI(1,:),im.ROI(2,:),im.image,'tag','SpatialImage');
end
positions = reshape([sites.position],length(data.sites(1).position),[]);
sc = scatter(positions(1,:),positions(2,:),'ButtonDownFcn',@selectSite,...
    'MarkerEdgeAlpha',0.3,'tag','sites');
sc.UserData.fig = fig;
pos = scatter(NaN,NaN,'r');
xlabel(ax,'X Position (um)');
ylabel(ax,'Y Position (um)');
colormap(fig,'gray');
axis(ax,'image');
set(ax,'ydir','normal');
hold(ax,'off');
ax(2) = axes('parent',pan_ax(1),'tag','SpectraAx'); hold(ax(2),'on');
ax(3) = axes('parent',pan_ax(2),'tag','OpenLoopAx'); hold(ax(3),'on');
ax(4) = axes('parent',pan_ax(3),'tag','ClosedLoopAx'); hold(ax(4),'on');
addlistener(ax(2),'XLim','PostSet',@xlim_changed);
addlistener(ax(3),'XLim','PostSet',@xlim_changed);
addlistener(ax(4),'XLim','PostSet',@xlim_changed);

% Constants and large structures go here
n = length(sites);
viewonly = p.Results.viewonly;
FitType = p.Results.FitType;
wavenm_range = 299792./prefs.freq_range; % Used when plotting
inds = p.Results.inds;
AmplitudeSensitivity = 1;
update_exp = {@update_spec, @update_open, @update_closed}; % Easily index by exp_id
colors = lines;

if isstruct(p.Results.Analysis)
    analysis = p.Results.Analysis;
else
    analysis = struct(...
        'fit',cell(n,3),...
        'amplitudes',NaN,...
        'widths',NaN,...
        'locations',NaN,...
        'background',NaN,...
        'index',NaN,... % Index into sites
        'ignore',[]);     % indices of experiments in the fit
end

% Frequently updated and small stuff here
site_index = 1;
busy = false;
new_data = false;

% Link UI control
set([fig, selector],'KeyPressFcn',@cycleSite);
update_all(); % Bypass changeSite since we have no previous site

if nargout
    varargout = {fig};
end

    function open_diagnostic(varargin)
        Experiments.AutoExperiment.SpecSlowScan.diagnostic(FullData,analysis);
    end

    function export_data(varargin)
        if nargin < 1 || ~isa(fig,'matlab.ui.Figure')
            [~,fig] = gcbo;
        end
        save_state();
        to_save = {'analysis','sites'};
        for j = 1:2
            if ~isempty(eval(to_save{j}))
                var_name = to_save{j};
                i = 1;
                while evalin('base', sprintf('exist(''%s'',''var'') == 1',var_name))
                    i = i + 1;
                    var_name = sprintf('%s%i',to_save{j},i);
                end
                if i > 1
                    answer = questdlg(sprintf('Would you like to export "%s" data to workspace as new variable "%s" or overwrite existing "%s"?',...
                        to_save{j},var_name,to_save{j}),'Export','Overwrite','New Variable','No','Overwrite');
                    if strcmp(answer,'Overwrite')
                        answer = 'Yes';
                        var_name = to_save{j};
                    end
                else
                    answer = questdlg(sprintf('Would you like to export "%s" data to workspace as new variable "%s"?',to_save{j},var_name),...
                        'Export','Yes','No','Yes');
                end
                if strcmp(answer,'Yes')
                    assignin('base',var_name,eval(to_save{j}))
                end
            end
        end
        new_data = false;
    end

    function closereq(~,~)
        % Export data to workspace if analysis exists
        try
            if new_data
                export_data(fig);
            end
        catch err
            delete(fig)
            rethrow(err);
        end
        delete(fig)
    end

    function changeSite(new_index)
        % Only function allowed to update site_index
        if busy; return; end
        % Save the current analysis before moving to next site
        save_state();
        site_index = new_index;
        update_all();
    end

    function selectSite(sc,eventdata)
        if eventdata.Button == 1
            [~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[sc.XData; sc.YData]','K',1);
            [~,ind] = min(D);
            changeSite(ind);
        end
    end

    function go_to(~,~)
        site = inputdlg(sprintf('Jump to site (between 1 and %i):',n),mfilename,1,{num2str(n)});
        if ~isempty(site)
            site_num = str2double(site{1});
            if ~isnan(site_num) && site_num <= n && site_num > 0
                changeSite(site_num);
            else
                errordlg(sprintf('"%s" is not a number between 1 and %i.',site{1},n),mfilename);
            end
        end
    end

    function cycleSite(~,eventdata)
        switch eventdata.Key
            case 'leftarrow'
                direction = -1;
            case 'rightarrow'
                direction = 1;
            otherwise % Ignore anything else
                return
        end
        ind = mod(site_index-1+direction,n)+1;
        changeSite(ind);
    end
%% Update UI methods
    function prepUI(ax,selector)
        set(selector,'Data',cell(0,10)); % Reset selector
        cla(ax,'reset'); hold(ax,'on');
    end
    function update_all()
        update_im();
        update_spec();
        update_open();
        update_closed();
    end
    function update_im()
        % Update spectrometer data (ax(1))
        site = sites(site_index);
        ax(1).Title.String = sprintf('Site %i/%i',site_index,n);
        set(pos,'xdata',site.position(1),'ydata',site.position(2));
    end
    function update_spec()
        % Update spectrometer data (analysis(:,1), selector(1), ax(2))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(2),selector(1));
        set(selector(1),'Data',cell(0,10)); % Reset selector
        cla(ax(2),'reset'); hold(ax(2),'on');
        exp_inds = fliplr(find(strcmp('Experiments.Spectrum',{site.experiments.name})));
        for i = exp_inds
            experiment = site.experiments(i);
            if ~isempty(experiment.data) && ~any(i == analysis(site_index,1).ignore)
                wavelength = experiment.data.wavelength;
                mask = and(wavelength>=min(wavenm_range),wavelength<=max(wavenm_range));
                plot(ax(2),wavelength(mask),experiment.data.intensity(mask),'tag','Spectra','color',colors(i,:));
                formatSelector(selector(1),experiment,i,1,site_index,colors(i,:));
            else
                formatSelector(selector(1),experiment,i,1,site_index);
            end
        end
        ax(2).Title.String = 'Spectrum';
        ax(2).XLabel.String = 'Wavelength (nm)';
        ax(2).YLabel.String = 'Intensity (a.u.)';
        if ~viewonly && ~isempty(findall(ax(2),'type','line'))
            attach_uifitpeaks(ax(2),analysis(site_index,1),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function update_open()
        % Update PLE open (analysis(:,2), selector(2), ax(3))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(3),selector(2));
        exp_inds = fliplr(find(strcmp('Experiments.SlowScan.Open',{site.experiments.name})));
        set_points = NaN(1,length(exp_inds));
        j = 1; % Loop counter (e.g. index into set_points)
        for i = exp_inds
            experiment = site.experiments(i);
            if ~isempty(experiment.data) &&  ~any(i == analysis(site_index,2).ignore)
                errorfill(experiment.data.data.freqs_measured,...
                        experiment.data.data.sumCounts,...
                        experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                        'parent',ax(3),'tag','OpenLoop','color',colors(i,:));
                set_points(j) = experiment.data.meta.prefs.freq_THz;
                formatSelector(selector(2),experiment,i,2,site_index,colors(i,:));
            else
                formatSelector(selector(2),experiment,i,2,site_index);
            end
            j = j + 1;
        end
        ylim = get(ax(3),'ylim');
        for i = 1:length(set_points)
            if ~isnan(set_points(i))
                plot(ax(3),set_points(i)+[0 0], ylim, '--', 'Color', colors(exp_inds(i),:),...
                    'handlevisibility','off','hittest','off');
            end
        end
        ax(3).Title.String = 'Open Loop SlowScan';
        ax(3).XLabel.String = 'Frequency (THz)';
        ax(3).YLabel.String = 'Counts';
        if ~viewonly && ~isempty(findall(ax(3),'type','line'))
            attach_uifitpeaks(ax(3),analysis(site_index,2),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function update_closed()
        % Update PLE closed (analysis(:,3), selector(3), ax(4))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(4),selector(3));
        exp_inds = fliplr(find(strcmp('Experiments.SlowScan.Closed',{site.experiments.name})));
        for i = exp_inds
            experiment = site.experiments(i);
            if ~isempty(experiment.data) &&  ~any(i == analysis(site_index,3).ignore)
                errorfill(experiment.data.data.freqs_measured,...
                        experiment.data.data.sumCounts,...
                        experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                        'parent',ax(4),'tag','ClosedLoop','color',colors(i,:));
                formatSelector(selector(3),experiment,i,3,site_index,colors(i,:));
            else
                formatSelector(selector(3),experiment,i,3,site_index);
            end
        end
        ax(4).Title.String = 'Closed Loop SlowScan';
        ax(4).XLabel.String = 'Frequency (THz)';
        ax(4).YLabel.String = 'Counts';
        if ~viewonly && ~isempty(findall(ax(4),'type','line'))
            attach_uifitpeaks(ax(4),analysis(site_index,3),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function formatSelector(selectorH,experiment,i,exp_ind,site_ind,rgb)
        if nargin < 6
            color = '';
        else
            hex = sprintf('#%02X%02X%02X',round(rgb*255));
            color = sprintf('<html><font color="%s">&#9724;</font></html>',hex);
        end
        date = datestr(experiment.tstart);
        if ~isempty(experiment.err)
            date = sprintf('<html><font color="red">%s</font></html>',date);
        elseif experiment.completed && ~experiment.skipped
            date = sprintf('<html><font color="green">%s</font></html>',date);
        end
        if isempty(experiment.tstop) % Errors cause empty
            duration = '-';
        else
            duration = char(experiment.tstop - experiment.tstart);
        end
        displayed = false;
        if ~any(i==analysis(site_ind,exp_ind).ignore)
            displayed = true;
        end
        selectorH.Data(end+1,:) = {displayed,color, i,...
                                   date,...
                                   experiment.continued,...
                                   experiment.redo_requested,...
                                   duration,...
                                   experiment.skipped,...
                                   experiment.completed,...
                                   ~isempty(experiment.err)};
    end
%% Callbacks
    function xlim_changed(~,eventdata)
        % Find fit line and redraw with more points
        ax_changed = eventdata.AffectedObject;
        uifitpeaks_lines = findobj(ax_changed,'tag','uifitpeaks');
        nlines = length(uifitpeaks_lines);
        xlim = ax_changed.XLim;
        for i = nlines:-1:1
            if isa(uifitpeaks_lines(i).UserData,'cfit')
                x = linspace(xlim(1),xlim(2),length(uifitpeaks_lines(i).XData));
                uifitpeaks_lines(i).XData = x;
                uifitpeaks_lines(i).YData = uifitpeaks_lines(i).UserData(x);
                return
            end
        end
    end
    function selector_click_callback(hObj,eventdata)
        if ~strcmp(eventdata.EventName,'CellSelection') ||...
                hObj.ColumnEditable(eventdata.Indices(2))
            return
        end
        exp_ind = hObj.Data{eventdata.Indices(1),3};
        errmsg = sites(sites_index).experiments(exp_ind).err;
        if ~isempty(errmsg)
            msgbox(getReport(errmsg),sprintf('Error (site: %i, exp: %i)',sites_index,exp_ind));
        end
    end
    function selector_edit_callback(hObj,eventdata)
        switch eventdata.Indices(2)
            case 1 % Display
                if busy
                    hObj.Data{eventdata.Indices(1),1} = ~hObj.Data{eventdata.Indices(1),1};
                    return
                end
                exp_ind = hObj.Data{eventdata.Indices(1),3};
                exp_type = hObj.UserData;
                mask = analysis(site_index,exp_type).ignore==exp_ind;
                if any(mask) % Remove it
                    analysis(site_index,exp_type).ignore(mask) = [];
                else % Add it
                    analysis(site_index,exp_type).ignore(end+1) = exp_ind;
                end
                update_exp{exp_type}();
            case 6 % Redo Request (no need to update_all)
                % Can only toggle most recent experiment
                % Find most recent age
                most_recent = min([hObj.Data{:,5}]);
                if hObj.Data{eventdata.Indices(1),5} ~= most_recent
                    errordlg('You can only toggle the most recent experiment.',mfilename);
                    % Toggle back
                    hObj.Data{eventdata.Indices(1),6} = ~hObj.Data{eventdata.Indices(1),6};
                else % Maybe this should go in save_state
                    exp_ind = hObj.Data{eventdata.Indices(1),3};
                    sites(site_index).experiments(exp_ind).redo_requested = hObj.Data{eventdata.Indices(1),6};
                end
        end
    end
%% UIfitpeaks adaptor
    function save_state()
        for i = 2:4 % Go through each data axis
            if ~isstruct(ax(i).UserData) || ~isfield(ax(i).UserData,'uifitpeaks_enabled')
                analysis(site_index,i-1).fit = [];
                analysis(site_index,i-1).amplitudes = NaN;
                analysis(site_index,i-1).locations = NaN;
                analysis(site_index,i-1).widths = NaN;
                analysis(site_index,i-1).background = NaN;
                analysis(site_index,i-1).index = NaN;
                % Uses can stay
                continue
            end
            fit_result = ax(i).UserData.pFit.UserData;
            new_data = true;
            analysis(site_index,i-1).index = inds(site_index);
            if ~isempty(fit_result)
                fitcoeffs = coeffvalues(fit_result);
                nn = (length(fitcoeffs)-1)/3; % 3 degrees of freedom per peak; subtract background
                analysis(site_index,i-1).fit = fit_result;
                analysis(site_index,i-1).amplitudes = fitcoeffs(1:nn);
                analysis(site_index,i-1).locations = fitcoeffs(nn+1:2*nn);
                if strcmpi(FitType,'gauss')
                    analysis(site_index,i-1).widths = fitcoeffs(2*nn+1:3*nn)*2*sqrt(2*log(2));
                else
                    analysis(site_index,i-1).widths = fitcoeffs(2*nn+1:3*nn);
                end
                analysis(site_index,i-1).background = fitcoeffs(3*nn+1);
            else
                analysis(site_index,i-1).fit = [];
                analysis(site_index,i-1).amplitudes = [];
                analysis(site_index,i-1).locations = [];
                analysis(site_index,i-1).widths = [];
                analysis(site_index,i-1).background = [];
            end
        end
    end
    function attach_uifitpeaks(ax,init,varargin)
        % Wrapper to attach uifitpeaks
        % Let uifitpeaks update keyboard fcn, but then wrap that fcn again
        if any(isnan(init.locations))
            uifitpeaks(ax,'fittype',FitType,varargin{:});
        else
            uifitpeaks(ax,'fittype',FitType,'init',init,varargin{:});
        end
        if fig.UserData.uifitpeaks_count == 1 % Only set on first creation
            fig.UserData.uifitpeaks_keypress_callback = get(fig,'keypressfcn');
            set([fig, selector],'keypressfcn',@keypress_wrapper);
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

end