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
%       [alt+] left/right arrows to change site fig.UserData.index. The alt is only
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
uimenu(file_menu,'Text','Export Data','callback',@export_data,'separator','on');
ax = subplot(1,5,[1 2],'parent',fig,'tag','SpatialImageAx');
hold(ax,'on');
if ~isempty(im)
    imagesc(ax,im.ROI(1,:),im.ROI(2,:),im.image,'tag','SpatialImage');
end
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
viewonly = p.Results.viewonly;
FitType = p.Results.FitType;
wavenm_range = 299792./prefs.freq_range; % Used when plotting
inds = p.Results.inds;

if isstruct(p.Results.Analysis)
    analysis = p.Results.Analysis;
else
    analysis = struct(...
        'fit',cell(n,3),...
        'amplitudes',NaN,...
        'widths',NaN,...
        'locations',NaN,...
        'background',NaN,...
        'index',NaN);
end

% Frequently updated and small stuff here
fig.UserData.index = 1;
busy = false;
new_data = false;

% Link UI control
fig.KeyPressFcn = @cycleSite;
update(); % Bypass changeSite since we have no previous site

if nargout
    varargout = {fig};
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
                var_name = sprintf('analysis%i',i);
            end
            answer = questdlg(sprintf('Would you like to export analysis data to workspace as "%s"?',var_name),...
                'Export Analysis','Yes','No','Yes');
            if strcmp(answer,'Yes')
                assignin('base',var_name,analysis)
            end
            new_data = false;
        end
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
        if busy
            warning('Chill! Busy still...');
            return
        end
        busy = true;
        % Save the current analysis before moving to next site
        save_state();
        fig.UserData.index = new_index;
        try
            update();
        catch err
            busy = false;
            rethrow(err)
        end
        busy = false;
    end

    function selectSite(sc,eventdata)
        if eventdata.Button == 1
            [~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[sc.XData; sc.YData]','K',1);
            [~,ind] = min(D);
            changeSite(ind);
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
        ind = mod(fig.UserData.index-1+direction,n)+1;
        changeSite(ind);
    end

    function update()
        site = sites(fig.UserData.index);
        % Image
        ax(1).Title.String = sprintf('Site %i/%i',fig.UserData.index,n);
        set(pos,'xdata',site.position(1),'ydata',site.position(2));
        
        cla(ax(2),'reset'); cla(ax(3),'reset'); cla(ax(4),'reset');
        hold(ax(2),'on'); hold(ax(3),'on'); hold(ax(4),'on');
        titles = {'Spectrum'};
        for i = find(strcmp('Experiments.Spectrum',{site.experiments.name}))
            experiment = site.experiments(i);
            if ~isempty(experiment.data)
                wavelength = experiment.data.wavelength;
                mask = and(wavelength>=min(wavenm_range),wavelength<=max(wavenm_range));
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
        set_points = [];
        cs = NaN(0,3);
        for i = find(strcmp('Experiments.SlowScan.Open',{site.experiments.name}))
            experiment = site.experiments(i);
            if ~isempty(experiment.data)
                ef = errorfill(experiment.data.data.freqs_measured,...
                        experiment.data.data.sumCounts,...
                        experiment.data.data.stdCounts*sqrt(experiment.prefs.samples),...
                        'parent',ax(3),'tag','OpenLoop');
                set_points(end+1) = experiment.data.meta.prefs.freq_THz;
                cs(end+1,:) = ef.line.Color;
            end
            if ~isempty(experiment.err)
                titles{end+1} = sprintf('\\rm\\color{red}\\fontsize{8}%i\\Rightarrow%s',...
                    i,strrep(strip(experiment.err.message),'\','\\')); % Escape backslash for tex interpreter
            end
        end
        ylim = get(ax(3),'ylim');
        for i = 1:length(set_points)
            plot(ax(3),set_points(i)+[0 0], ylim, '--', 'Color', cs(i,:),'handlevisibility','off','hittest','off');
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
        if ~viewonly
            if ~isempty(findall(ax(2),'type','line'))
                attach_uifitpeaks(ax(2),analysis(fig.UserData.index,1),...
                    'AmplitudeSensitivity',1);
            end
            if ~isempty(findall(ax(3),'type','line'))
                attach_uifitpeaks(ax(3),analysis(fig.UserData.index,2),...
                    'AmplitudeSensitivity',1);
            end
            if ~isempty(findall(ax(4),'type','line'))
                attach_uifitpeaks(ax(4),analysis(fig.UserData.index,3),...
                    'AmplitudeSensitivity',1);
            end
        end
    end
%% UIfitpeaks adaptor
    function save_state()
        for i = 2:4 % Go through each data axis
            if ~isstruct(ax(i).UserData) || ~isfield(ax(i).UserData,'uifitpeaks_enabled')
                continue
            end
            fit_result = ax(i).UserData.pFit.UserData;
            new_data = true;
            analysis(fig.UserData.index,i-1).index = inds(fig.UserData.index);
            if ~isempty(fit_result)
                fitcoeffs = coeffvalues(fit_result);
                nn = (length(fitcoeffs)-1)/3; % 3 degrees of freedom per peak; subtract background
                analysis(fig.UserData.index,i-1).fit = fit_result;
                analysis(fig.UserData.index,i-1).amplitudes = fitcoeffs(1:nn);
                analysis(fig.UserData.index,i-1).locations = fitcoeffs(nn+1:2*nn);
                if strcmpi(FitType,'gauss')
                    analysis(fig.UserData.index,i-1).widths = fitcoeffs(2*nn+1:3*nn)*2*sqrt(2*log(2));
                else
                    analysis(fig.UserData.index,i-1).widths = fitcoeffs(2*nn+1:3*nn);
                end
                analysis(fig.UserData.index,i-1).background = fitcoeffs(3*nn+1);
            else
                analysis(fig.UserData.index,i-1).fit = [];
                analysis(fig.UserData.index,i-1).amplitudes = [];
                analysis(fig.UserData.index,i-1).locations = [];
                analysis(fig.UserData.index,i-1).widths = [];
                analysis(fig.UserData.index,i-1).background = [];
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

end