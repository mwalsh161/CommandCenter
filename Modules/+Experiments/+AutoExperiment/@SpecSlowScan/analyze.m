function varargout = analyze(data,varargin)
%ANALYZE Examine data from all sites
%   Inputs:
%       data: data produced by GetData method
%       [Analysis]: An analysis struct produced by this function
%       [FitType]: "gauss", "lorentz", or "voigt" (default "gauss")
%       [inds]: array of indices to mask full dataset (default: all data).
%          This will also filter analysis if provided.
%       [viewonly]: do not begin uifitpeaks on the axes
%       [new]: arrow navigation will go to nearest new site (e.g. continued = 0)
%       [block]: (false) Calls uiwait internally and will return analysis
%          when user closes figure.
%   Outputs:
%       (fig): Figure handle
%       (analysis): analysis struct (use with block=true).
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
%   Analysis data:
%     Nx3 struct array with fields: (N is number of sites, 3 corresponds to experiments)
%       amplitudes - Nx1 double
%       widths - Nx1 double (all FWHM)
%       locations - Nx1 double
%       background - 1x1 double
%       fit - cfit object or empty if no peaks found
%       index - index into data.sites. If NaN, this wasn't analyzed
%   Can export/save from file menu
%   Will be prompted to export analysis data to base workspace upon closing
%   figure if no export since last analysis data update_all (NOTE this is only
%   saved when switching sites).
%       This will not overwrite previously exported data sets unless
%       specified.

p = inputParser();
addParameter(p,'Analysis',[],@isstruct);
addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz','voigt'})));
addParameter(p,'inds',1:length(data.data.sites),@(n)validateattributes(n,{'numeric'},{'vector'}));
addParameter(p,'viewonly',false,@islogical);
addParameter(p,'new',false,@islogical);
addParameter(p,'block',false,@islogical);
parse(p,varargin{:});

prefs = data.meta.prefs;
FullData = data;
data = FullData.data;
im = data.image.image;
sites = data.sites(p.Results.inds);


fig = figure('name',mfilename,'numbertitle','off','CloseRequestFcn',@closereq);
fig.Position(3) = fig.Position(3)*2;
file_menu = findall(fig,'tag','figMenuFile');
uimenu(file_menu,'Text','Go to Index','callback',@go_to,'separator','on');
uimenu(file_menu,'Text','Save Analysis','callback',@save_data);
uimenu(file_menu,'Text','Export Analysis','callback',@export_data);
uimenu(file_menu,'Text','Diagnostic Plot','callback',@open_diagnostic);
bg(1) = uipanel(fig,'units','normalized','position',[0   0 1/5 1],'BorderType','none');
bg(2) = uipanel(fig,'units','normalized','position',[1/5 0 4/5 1],'BorderType','none');
splitPan(1) = Base.SplitPanel(bg(1),bg(2),'horizontal');
set(splitPan(1).dividerH,'BorderType','etchedin')
inner(1) = uipanel(bg(2),'units','normalized','position',[0 1/4 1 3/4],'BorderType','none');
inner(2) = uipanel(bg(2),'units','normalized','position',[0 0   1 1/4],'BorderType','none');
splitPan(2) = Base.SplitPanel(inner(1),inner(2),'vertical');
set(splitPan(2).dividerH,'BorderType','etchedin')
for i_ax = 1:4
    pan_ax(i_ax) = uipanel(inner(1),'units','normalized','position',[(i_ax-1)/4 0 1/4 1],'BorderType','none');
    selector(i_ax) = uitable(inner(2),'ColumnName',{'','',  'i',  'Datetime','Age','Redo','Duration','Skipped','Completed','Error'},...
                                  'ColumnEditable',[true,false,false,false,     false,true,  false,     false,    false,      false],...
                                  'ColumnWidth',   {15,15,   20,   120,       25,   35,    50,        50,       70,         40},...
                                  'units','normalized','Position',[(i_ax-1)/4 0 1/4 1],...
                                  'CellEditCallback',@selector_edit_callback,...
                                  'CellSelectionCallback', @selector_click_callback);
    selector(i_ax).UserData = i_ax;
end
% Add some help tooltips
selector(2).Tooltip = 'Dashed line corresponds to setpoint of scan at 50%.';
selector(3).Tooltip = 'Arrows on x-axis correpond to super-res set points';
selector(4).Tooltip = ['Arrows on Closed Loop SlowScan axis correspond to', newline,...
                       'the setpoints for the scan with the same color box.'];
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
ax(5) = axes('parent',pan_ax(4),'tag','SuperResAx'); hold(ax(5),'on');
addlistener(ax(2),'XLim','PostSet',@xlim_changed);
addlistener(ax(3),'XLim','PostSet',@xlim_changed);
addlistener(ax(4),'XLim','PostSet',@xlim_changed);

% Axes-specific menus
c = uicontextmenu();
m(1) = uimenu(c,'label','Grah side-by-side','callback',@swap_superres_display,'Checked','on','UserData',struct('id',1));
m(2) = uimenu(c,'label','Separate color channel overlay','callback',@swap_superres_display,'UserData',struct('id',2));
% Makes it easy to swap in callback:
c.UserData.id = 1;
m(1).UserData.other = m(2);
m(2).UserData.other = m(1);
ax(5).UIContextMenu = c;

% Constants and large structures go here
block = p.Results.block;
n = length(sites);
filter_new = p.Results.new;
viewonly = p.Results.viewonly;
FitType = p.Results.FitType;
wavenm_range = 299792./prefs.freq_range; % Used when plotting
inds = p.Results.inds;
AmplitudeSensitivity = 1;
update_exp = {@update_spec, @update_open, @update_closed, @update_superres}; % Easily index by exp_id
colors = lines(7);

% Frequently updated and small stuff here
site_index = 1;
busy = false;
new_data = false;
if isstruct(p.Results.Analysis)
    analysis = p.Results.Analysis;
    % Backwards compatibility
    if ~isfield(analysis,'sites')
        analysis = struct('sites',analysis);
        analysis.nm2THz = [];
        analysis.gof = [];
        warning('Found old format of analysis; updated to new format.')
        new_data = true;
    end
    if ~isfield(analysis.sites,'redo')
        for isite = 1:size(analysis,1)
            for jexp = 1:size(analysis,2)
                analysis.sites(isite,jexp).redo = false;
            end
        end
        new_data = true;
        warning('Added redo flag to loaded analysis.')
    end
    if ~isfield(analysis.sites,'ignore')
        for isite = 1:size(analysis,1)
            for jexp = 1:size(analysis,2)
                analysis.sites(isite,jexp).ignore = [];
            end
        end
        new_data = true;
        warning('Added ignore flag to loaded analysis.')
    end
    if size(analysis.sites,2) == 3
        for ii = 1:size(sites,1)
            analysis.sites(ii,4).amplitudes = NaN;
            analysis.sites(ii,4).widths = NaN;
            analysis.sites(ii,4).locations = NaN;
            analysis.sites(ii,4).background = NaN;
            analysis.sites(ii,4).index = NaN;
            analysis.sites(ii,4).redo = false;
        end
        new_data = true;
        warning('Added 4th column to analysis.sites')
    end
    % Filter with inds
    analysis.sites = analysis.sites(p.Results.inds,:);
else
    analysis.nm2THz = [];
    analysis.gof = [];
    analysis.sites = struct(...
        'fit',cell(n,4),...
        'amplitudes',NaN,...
        'widths',NaN,...
        'locations',NaN,...
        'background',NaN,...
        'index',NaN,... % Index into sites
        'redo',false,...
        'ignore',[]);     % indices of experiments in the fit
end

% Link UI control
set([fig, selector],'KeyPressFcn',@cycleSite);
update_all(); % Bypass changeSite since we have no previous site

block = p.Results.block;
if block
    uiwait(fig);
end

if nargout
    varargout = {fig,analysis};
end

    function open_diagnostic(varargin)
        save_state();
        try
            [nm2THz,gof] = Experiments.AutoExperiment.SpecSlowScan.diagnostic(FullData,analysis.sites);
            if ~isequal(nm2THz,0)
                answer = questdlg('New winspec calibration fit using analyzed peaks in data; add to analysis?','WinSpec Calibration Fit','Yes','No','Yes');
                if strcmp(answer,'Yes')
                    analysis.nm2THz = nm2THz;
                    analysis.gof = gof;
                    new_data = true;
                end
            end
        catch err
            errordlg(getReport(err,'extended','hyperlinks','off'));
        end
    end

    function export_data(varargin)
        if nargin < 1 || ~isa(fig,'matlab.ui.Figure')
            [~,fig] = gcbo;
        end
        save_state();
        if ~isempty(analysis)
            var_name = 'analysis';
            i = 1;
            while evalin('base', sprintf('exist(''%s'',''var'') == 1',var_name))
                i = i + 1;
                var_name = sprintf('%s%i','analysis',i);
            end
            if i > 1
                answer = questdlg(sprintf('Would you like to export "analysis" data to workspace as new variable "%s" or overwrite existing "analysis"?',...
                    var_name),'Export','Overwrite','New Variable','No','Overwrite');
                if strcmp(answer,'Overwrite')
                    answer = 'Yes';
                    var_name = 'analysis';
                end
            else
                answer = questdlg(sprintf('Would you like to export "analysis" data to workspace as new variable "%s"?',var_name),...
                    'Export','Yes','No','Yes');
            end
            if strcmp(answer,'Yes')
                assignin('base',var_name,analysis)
            end
        end
        new_data = false;
    end
    function save_data(varargin)
        save_state();
        last = '';
        if ispref(obj.namespace,'last_save')
            last = getpref(obj.namespace,'last_save');
        end
        [file,path] = uiputfile('*.mat','Save Analysis',last);
        if ~isequal(file,0)
            setpref(obj.namespace,'last_save',path);
            [~,~,ext] = fileparts(file);
            if isempty(ext) % Add extension if not specified
                file = [file '.mat'];
            end
            save(fullfile(path,file),'-struct','analysis');
        end
        new_data = false;
    end

    function closereq(~,~)
        save_state();
        if ~block % If block; we are returning data; assume no save expected
            % Export data to workspace if analysis exists
            try
                if new_data
                    export_data(fig);
                end
            catch err
                delete(fig)
                rethrow(err);
            end
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
        ind = site_index;
        for i = 1:n % Just go through sites once
            switch eventdata.Key
                case 'leftarrow'
                    direction = -1;
                case 'rightarrow'
                    direction = 1;
                otherwise % Ignore anything else
                    return
            end
            ind = mod(ind-1+direction,n)+1;
            if filter_new && ~any([sites(ind).experiments.continued]==0)
                continue
            end
            changeSite(ind);
            return
        end
        errordlg('No new sites found; try relaunching without new flag set to true.')
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
        update_superres();
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
        exp_inds = fliplr(find(strcmp('Experiments.Spectrum',{site.experiments.name})));
        for i = 1:length(exp_inds)
            experiment = site.experiments(exp_inds(i));
            if ~isempty(experiment.data) && ~any(exp_inds(i) == analysis.sites(site_index,1).ignore)
                wavelength = experiment.data.wavelength;
                mask = and(wavelength>=min(wavenm_range),wavelength<=max(wavenm_range));
                plot(ax(2),wavelength(mask),experiment.data.intensity(mask),'tag','Spectra','color',colors(i,:));
                formatSelector(selector(1),experiment,exp_inds(i),1,site_index,colors(mod(i-1,size(colors,1))+1,:));
            else
                formatSelector(selector(1),experiment,exp_inds(i),1,site_index);
            end
        end
        ax(2).Title.String = 'Spectrum';
        ax(2).XLabel.String = 'Wavelength (nm)';
        ax(2).YLabel.String = 'Intensity (a.u.)';
        if ~viewonly && ~isempty(findall(ax(2),'type','line'))
            attach_uifitpeaks(ax(2),analysis.sites(site_index,1),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function update_open()
        % Update PLE open (analysis.sites(:,2), selector(2), ax(3))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(3),selector(2));
        exp_inds = fliplr(find(strcmp('Experiments.SlowScan.Open',{site.experiments.name})));
        setpt_plts = gobjects(1,length(exp_inds));
        for i = 1:length(exp_inds)
            experiment = site.experiments(exp_inds(i));
            if ~isempty(experiment.data) &&  ~any(exp_inds(i) == analysis.sites(site_index,2).ignore)
                errorfill(experiment.data.data.freqs_measured,...
                        experiment.data.data.sumCounts,...
                        experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                        'parent',ax(3),'tag','OpenLoop','color',colors(mod(i-1,size(colors,1))+1,:));
                set_point = experiment.prefs.freq_THz;
                setpt_plts(i) = plot(ax(3),set_point+[0 0], [NaN,NaN], '--', 'Color', colors(mod(i-1,size(colors,1))+1,:),...
                    'handlevisibility','off','hittest','off');
                formatSelector(selector(2),experiment,exp_inds(i),2,site_index,colors(mod(i-1,size(colors,1))+1,:));
            else
                formatSelector(selector(2),experiment,exp_inds(i),2,site_index);
            end
        end
        ylim = get(ax(3),'ylim');
        set(setpt_plts(isgraphics(setpt_plts)),'YData',ylim);
        ax(3).Title.String = 'Open Loop SlowScan';
        ax(3).XLabel.String = 'Frequency (THz)';
        ax(3).YLabel.String = 'Counts';
        if ~viewonly && ~isempty(findall(ax(3),'type','line'))
            attach_uifitpeaks(ax(3),analysis.sites(site_index,2),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function update_closed()
        % Update PLE closed (analysis.sites(:,3), selector(3), ax(4))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(4),selector(3));
        exp_inds = fliplr(find(strcmp('Experiments.SlowScan.Closed',{site.experiments.name})));
        for i = 1:length(exp_inds)
            experiment = site.experiments(exp_inds(i));
            if ~isempty(experiment.data) &&  ~any(exp_inds(i) == analysis.sites(site_index,3).ignore)
                errorfill(experiment.data.data.freqs_measured,...
                        experiment.data.data.sumCounts,...
                        experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                        'parent',ax(4),'tag','ClosedLoop','color',colors(mod(i-1,size(colors,1))+1,:));
                formatSelector(selector(3),experiment,exp_inds(i),3,site_index,colors(mod(i-1,size(colors,1))+1,:));
            else
                formatSelector(selector(3),experiment,exp_inds(i),3,site_index);
            end
        end
        ax(4).Title.String = 'Closed Loop SlowScan';
        ax(4).XLabel.String = 'Frequency (THz)';
        ax(4).YLabel.String = 'Counts';
        if ~viewonly && ~isempty(findall(ax(4),'type','line'))
            attach_uifitpeaks(ax(4),analysis.sites(site_index,3),...
                'AmplitudeSensitivity',AmplitudeSensitivity);
        end
        catch err
            busy = false;
            rethrow(err);
        end
        busy = false;
    end
    function update_superres()
        % Update PLE closed (analysis.sites(:,4), selector(4), ax(5))
        if busy; error('Busy!'); end
        busy = true;
        try
        site = sites(site_index);
        prepUI(ax(5),selector(4));
        delete(findobj(ax(4),'tag','superres')); % Clean up locators on closed-loop ax
        exp_inds = fliplr(find(strcmp('Experiments.SuperResScan',{site.experiments.name})));
        cs = reshape(lines,[],1,3); % In preparation for RGB image
        if ~isempty(exp_inds)
            % All experiments should be the same and x/y should be same
            % First experiment may fail, but the prefs field will always exist
            sz = 0;
            % A bit awkward, because we can't filter yet since even failed exps
            % need to go through formatSelector; so just hang on to this
            successful_ind = exp_inds([site.experiments(exp_inds).completed] & ~[site.experiments(exp_inds).skipped]);
            successful_ind = find(successful_ind,1);
            if any(successful_ind)
                sz = length(str2num(site.experiments(exp_inds(successful_ind)).prefs.x_points)); %#ok<ST2NM> (need str2num to perfrom eval)
            end
            rm = true(1,length(exp_inds)); % Remove experiments that aren't legit
            if ax(5).UIContextMenu.UserData.id == 1 % gray, side by side
                multi = NaN(sz+2,sz*2+2,3,length(exp_inds)); % 2*sz in x to drop repump and res images
            elseif ax(5).UIContextMenu.UserData.id == 2 % Color overlay
                multi = NaN(sz+2,sz+2,3,length(exp_inds));
            end
            for i = 1:length(exp_inds)
                experiment = site.experiments(exp_inds(i));
                formatSelector(selector(4),experiment,exp_inds(i),4,site_index,cs(i,1,:));
                if experiment.skipped
                    continue
                end
                freq = experiment.prefs.frequency;
                if ~isempty(experiment.data) &&  ~any(exp_inds(i) == analysis.sites(site_index,4).ignore)
                    % Add marker on closed loop axes
                    plot(ax(4),freq, ax(4).YLim(1),'Color',cs(i,1,:),'MarkerFaceColor',cs(i,1,:),'Marker','v','MarkerSize',5,'tag','superres');
                    repumpGray = squeeze(nanmean(experiment.data.data.sumCounts(:,:,:,1),1))';
                    resGray = squeeze(nanmean(experiment.data.data.sumCounts(:,:,:,2),1))';
                    if ax(5).UIContextMenu.UserData.id == 1 % gray, side by side
                        gray = cat(2,repumpGray/max(repumpGray(:)), resGray/max(resGray(:)));
                        color = cat(3, gray, gray, gray);
                        bordered = ones(sz+2,sz*2+2,3).*cs(i,1,:);
                    elseif ax(5).UIContextMenu.UserData.id == 2 % Color overlay
                        color = zeros(sz,sz,3);
                        color(:,:,1) = resGray/median(repumpGray(:))/4;
                        color(:,:,2) = repumpGray/median(repumpGray(:))/4;
                        bordered = ones(sz+2,sz+2,3).*cs(i,1,:);
                    end
                    bordered(2:end-1,2:end-1,:) = color;
                    multi(:,:,:,i) = bordered;
                    rm(i) = false;
                else
                    rm(i) = true;
                end
            end
            multi(:,:,:,rm) = [];
            nims = size(multi,4);
            if nims == 1
                imH = imshow(multi,'parent',ax(5));
                imH.UIContextMenu = ax(5).UIContextMenu;
            elseif nims > 1
                panel_sz = getpixelposition(ax(5).Parent);
                if ax(5).UIContextMenu.UserData.id == 1 % gray, side by side
                    ncols = max(1,floor(panel_sz(3)/sqrt(2*prod(panel_sz(3:4))/nims))); % Assumes square ims
                    imH = montage(multi,'parent',ax(5),'Size',[NaN,ncols],'ThumbnailSize',[sz sz*2]+2);
                elseif ax(5).UIContextMenu.UserData.id == 2 % Color overlay
                    ncols = max(1,floor(panel_sz(3)/sqrt(prod(panel_sz(3:4))/nims))); % Assumes square ims
                    imH = montage(multi,'parent',ax(5),'Size',[NaN,ncols],'ThumbnailSize',[sz sz]+2);
                end
                imH.UIContextMenu = ax(5).UIContextMenu;
            end
            ax(5).Title.String = 'SuperRes Scan';
            set(ax(5),'ydir','normal');
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
        if ~any(i==analysis.sites(site_ind,exp_ind).ignore)
            displayed = true;
        end
        % Analysis redo should be flexible
        analysis_redo = false;
        if ~isempty(analysis.sites(site_ind,exp_ind).redo)
            analysis_redo = analysis.sites(site_ind,exp_ind).redo;
        end
        selectorH.Data(end+1,:) = {displayed,color, i,...
                                   date,...
                                   experiment.continued,...
                                   analysis_redo,...
                                   duration,...
                                   experiment.skipped,...
                                   experiment.completed,...
                                   ~isempty(experiment.err)};
    end
%% Callbacks
    function swap_superres_display(hObj,~)
        if hObj.UserData.id == hObj.Parent.UserData.id; return; end  % Nothing to do
        hObj.Checked = 'on'; % Select this one
        hObj.UserData.other.Checked = 'off'; % Unselect the other one
        hObj.Parent.UserData.id = hObj.UserData.id;
        update_superres();
    end
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
        if isempty(eventdata.Indices) || eventdata.Indices(2)~=10
            return
        end
        exp_ind = hObj.Data{eventdata.Indices(1),3};
        err = sites(site_index).experiments(exp_ind).err;
        if ~isempty(err)
            errmsg = getReport(err,'extended','hyperlinks','off');
            errmsg = strrep(errmsg,[newline newline],newline);
            f = figure('name',sprintf('Error (site: %i, exp: %i)',site_index,exp_ind),...
                'numbertitle','off','menubar','none','toolbar','none');
            uicontrol(f,'units','normalized','position',[0,0,1,1],'style','edit',...
                'string',errmsg,'max',Inf,...
                'HorizontalAlignment','left');
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
                mask = analysis.sites(site_index,exp_type).ignore==exp_ind;
                if any(mask) % Remove it
                    analysis.sites(site_index,exp_type).ignore(mask) = [];
                else % Add it
                    analysis.sites(site_index,exp_type).ignore(end+1) = exp_ind;
                end
                update_exp{exp_type}();
            case 6 % Redo Request
                state = hObj.Data{eventdata.Indices(1),6};
                % Do it for all others
                for i = 1:length([hObj.Data{:,5}])
                    if i == eventdata.Indices(1); continue; end
                    hObj.Data{i,6} = state;
                end
        end
    end
%% UIfitpeaks adaptor
    function save_state()
        for i = 2:5 % Go through each data axis
            % Get redo flag for most recent
            most_recent = min([selector(i-1).Data{:,5}]) == [selector(i-1).Data{:,5}];
            analysis.sites(site_index,i-1).redo = any([selector(i-1).Data{most_recent,6}]);
            if ~isstruct(ax(i).UserData) || ~isfield(ax(i).UserData,'uifitpeaks_enabled')
                analysis.sites(site_index,i-1).fit = [];
                analysis.sites(site_index,i-1).amplitudes = NaN;
                analysis.sites(site_index,i-1).locations = NaN;
                analysis.sites(site_index,i-1).widths = NaN;
                analysis.sites(site_index,i-1).background = NaN;
                analysis.sites(site_index,i-1).index = NaN;
                % "uses" and "redo" can stay untouched
                continue
            end
            fit_result = ax(i).UserData.pFit.UserData;
            new_data = true;
            analysis.sites(site_index,i-1).index = inds(site_index);
            if ~isempty(fit_result)
                fitcoeffs = coeffvalues(fit_result);
                if strcmpi(FitType,'voigt')
                    nn = (length(fitcoeffs)-1)/4; % 4 degrees of freedom per peak for voigt; subtract background
                else
                    nn = (length(fitcoeffs)-1)/3; % 3 degrees of freedom per peak; subtract background
                end
                analysis.sites(site_index,i-1).fit = fit_result;
                analysis.sites(site_index,i-1).amplitudes = fitcoeffs(1:nn);
                analysis.sites(site_index,i-1).locations = fitcoeffs(nn+1:2*nn);
                if strcmpi(FitType,'gauss')
                    analysis.sites(site_index,i-1).widths = fitcoeffs(2*nn+1:3*nn)*2*sqrt(2*log(2));
                else
                    analysis.sites(site_index,i-1).widths = fitcoeffs(2*nn+1:3*nn);
                end
                if strcmpi(FitType,'voigt')
                    analysis.sites(site_index,i-1).etas = fitcoeffs(3*nn+2:4*nn+1);
                end
                analysis.sites(site_index,i-1).background = fitcoeffs(3*nn+1);
            else
                analysis.sites(site_index,i-1).fit = [];
                analysis.sites(site_index,i-1).amplitudes = [];
                analysis.sites(site_index,i-1).locations = [];
                analysis.sites(site_index,i-1).widths = [];
                analysis.sites(site_index,i-1).background = [];
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