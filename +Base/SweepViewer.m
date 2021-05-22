classdef SweepViewer < handle

	properties (SetAccess=private)
		s = [];		% Parent sweep of type `Base.Sweep`

		ax = [];	% MATLAB Axes object where the data will be plotted.
		panel = [];	% Struct containing panel where viewer info will be displayed.

        menus = []; 

		sp = {};	% Child processed scans of type `Base.ScanProcessed`.

        listeners = struct('data', [], 'x', [], 'y', []);
	end

	properties (Hidden, SetAccess=private)          % Processed scan settings
		names = 	{'R', 'G', 'B'}                                
		colors = 	{[1 0 0], [0 1 0], [0 0 1]};
		linewidth = 2;
		alpha = .7;
    end

	properties (Constant, Hidden)                   % Pointer settings
		pnames = 		{'selpix',      'selpnt',       'value'};
		pcolors = 		{[1, 1, 0, .6], [1, 1, 0, .8],  [0, 1, 1, .8]};
		plinewidth = 	[3,             2,              2];
		plinetype = 	{'o-',          'o--',          'o-'};
	end

	properties (Hidden)                   % Pointer settings
		lastclick = 0;
        doubleclicksec = .2;
	end

	properties (SetAccess=private)                  % Display objects for different situations.
		txt = {};	% Text `text`s for 0D situations, along with
		plt = {};	% 1D line `plot()`s for data
		img = [];	% 2D image `image()` for data
		ptr = {};	% Cursor location `+` plots
        ptrData = [];
    end

	properties (Hidden, Access={?Base.SweepViewer, ?Base.SweepProcessed})
        drawnowLast = 0;
        timerposted = false;
        rendering = false;
    end
	properties (Constant, Hidden)
        fpsTarget = 5;
    end

	properties (SetObservable, SetAccess=private)   % 
		axesDisplayed = []                          % Which dimensions are selected to be displayed (e.g. which as x, which as y). Integers according to the corresponding index in displayAxesObjects.
    end
	properties (SetAccess=private)                  % 
		displayAxesObjects = {}
		displayAxesScans = {}
		displayAxesMeasNum = [];
		displayAxesSubdata = {};
    end
	properties (Hidden, Constant)                   % 
		axesDisplayedNames = {'x', 'y'};            % Names of the dimensions that can be displayed by the `ScanViewer`
	end

	methods
		function obj = SweepViewer(s_, ax_, varargin)
            if isempty(ax_)
                f = figure('units', 'pixels', 'numbertitle', 'off', 'MenuBar', 'None');
                obj.ax = axes(f);
                
                obj.ax.Position = [.1, .1, .85, .85];
%                 obj.ax.Units
%                 
%                 error('sdfs')
            else
                obj.ax = ax_;
                obj.ax.Toolbar = [];
            end
			obj.s = s_;

			obj.displayAxesObjects =    [{Prefs.Empty}      obj.s.sdims];
			obj.displayAxesScans =      [{NaN} 				obj.s.sscans];
			obj.displayAxesMeasNum = 	[-1                 zeros(1, length(obj.s.sscans))];
            
			obj.displayAxesSubdata(1:(length(obj.s.sscans)+1)) = {''};

            kk = 1;
            
            for ii = 1:length(obj.s.measurements_)
                m = obj.s.measurements_{ii};

                sd = m.subdata;
                dims_ =  m.getDims;
                scans_ = m.getScans;
                
                for jj = 1:length(sd)
                    if numel(dims_.(sd{jj})) > 0
                        obj.displayAxesMeasNum =        [obj.displayAxesMeasNum         kk * ones(1, numel(dims_.(sd{jj})))];
                        obj.displayAxesObjects =        [obj.displayAxesObjects         dims_.(sd{jj})];
                        obj.displayAxesScans =          [obj.displayAxesScans           scans_.(sd{jj})];
                    end

                    kk = kk + 1;
                end
                
                obj.displayAxesMeasNum(1) = -kk+1;
            end
            
            damn = obj.displayAxesMeasNum
            
            sd = obj.s.subdata;
            
            if size(sd,1) > 1
                sd = sd';
            end
            
            obj.displayAxesSubdata = [obj.displayAxesSubdata sd];

			A = length(obj.axesDisplayedNames);
			obj.axesDisplayed = (1:A)+1;
			obj.axesDisplayed(obj.axesDisplayed > length(obj.displayAxesObjects)) = 1;

            obj.ax.Visible = 'off';
			obj.makePlots();

			% First, setup the panel.
            if ~isempty(varargin)
                p = varargin{1};
            else
                f = figure('units', 'pixels', 'Position', [100,100,300,500], 'numbertitle', 'off', 'MenuBar', 'None');
                p = uipanel(f);
            end
            
            obj.panel.panel = p;
            obj.panel.tabgroup = [];
            obj.panel.panel.Visible = 'off';
            obj.makePanel();

			N = length(obj.colors);
            for ii = 1:N
                obj.sp{ii} = Base.SweepProcessed(obj.s, obj, ii);
            end
            obj.panel.tabgroup.SelectedTab = obj.sp{1}.tab.tab;

            obj.setAxis(1, obj.axesDisplayed(1))

            prop = findprop(obj.s, 'data');
            obj.listeners.data = event.proplistener(obj.s, prop, 'PostSet', @obj.datachanged_Callback);

            obj.process();
            
            drawnow;
            
            obj.ax.Visible = 'on';
            obj.panel.panel.Visible = 'on';
        end

        function makeMenu(obj)
            obj.menus.ctsMenu(1) = uimenu(obj.menus.menu, 'Label', ['R: ~~~~ ' char(177) ' ~~~~ --'], 'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{1});
            obj.menus.ctsMenu(2) = uimenu(obj.menus.menu, 'Label', ['G: ~~~~ ' char(177) ' ~~~~ --'], 'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{2});
            obj.menus.ctsMenu(3) = uimenu(obj.menus.menu, 'Label', ['B: ~~~~ ' char(177) ' ~~~~ --'], 'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{3});

            uimenu(obj.menus.menu, 'Label', 'Set as Minimum', 'Callback', {@obj.minmax_Callback, 0}, 'Separator', 'on');
            uimenu(obj.menus.menu, 'Label', 'Set as Maximum', 'Callback', {@obj.minmax_Callback, 1});
            
            obj.menus.indMenu = uimenu(obj.menus.menu, 'Label', 'Index: [ ~~~~, ~~~~ ]',          'Callback', @copyLabelToClipboard, 'Separator', 'on');
            obj.menus.pixMenu = uimenu(obj.menus.menu, 'Label', 'Pixel: [ ~~~~ --, ~~~~ -- ]',    'Callback', @copyLabelToClipboard);
            obj.menus.posMenu = uimenu(obj.menus.menu, 'Label', 'Position: [ ~~~~ --, ~~~~ -- ]', 'Callback', @copyLabelToClipboard);

            uimenu(obj.menus.menu, 'Label', 'Goto Pixel', 'Callback', {@obj.gotoPostion_Callback, 1, 0}, 'Separator', 'on'); %#ok<*NASGU>
            uimenu(obj.menus.menu, 'Label', 'Goto Position', 'Callback', {@obj.gotoPostion_Callback, 0, 0});
                
%             mGoto = uimenu(obj.menus.menu,  'Label', 'Goto', 'Separator', 'on');
%                 uimenu(mGoto,               'Label', 'Selected Position',           'Callback', {@obj.gotoPostion_Callback, 1, 0}); %#ok<*NASGU>
%                 uimenu(mGoto,               'Label', 'Selected Pixel',              'Callback', {@obj.gotoPostion_Callback, 0, 0});
%                 uimenu(mGoto,               'Label', 'Selected Position And Slice', 'Callback', {@obj.gotoPostion_Callback, 1, 1}, 'Enable', 'off');
%                 uimenu(mGoto,               'Label', 'Selected Pixel And Slice',    'Callback', {@obj.gotoPostion_Callback, 0, 1}, 'Enable', 'off');
                
%             mNorm = uimenu(obj.menus.menu,  'Label', 'Normalization');
%                 uimenu(mNorm,               'Label', 'Set as Minimum',              'Callback', {@obj.minmax_Callback, 0});
%                 uimenu(mNorm,               'Label', 'Set as Maximum',              'Callback', {@obj.minmax_Callback, 1});
%                 uimenu(mNorm,               'Label', 'Normalize All Slices',        'Callback', {@obj.normalizeSlice_Callback, 0});
%                 uimenu(mNorm,               'Label', 'Normalize This Slice',        'Callback', {@obj.normalizeSlice_Callback, 1});

%             mCount = uimenu(menu,               'Label', 'Counter'); %, 'Enable', 'off');
%                 mcOpen =    uimenu(mCount,      'Label', 'Open',                        'Callback',  @obj.openCounter_Callback);
%                 mcOpenAt =  uimenu(mCount,      'Label', 'Open at...');
%                     uimenu(mcOpenAt,    'Label', 'Selected Position',           'Callback', {@obj.openCounterAtPoint_Callback, 1, 0});
%                     uimenu(mcOpenAt,    'Label', 'Selected Pixel',              'Callback', {@obj.openCounterAtPoint_Callback, 0, 0});
%                     uimenu(mcOpenAt,    'Label', 'Selected Position And Layer', 'Callback', {@obj.openCounterAtPoint_Callback, 1, 1});
%                     uimenu(mcOpenAt,    'Label', 'Selected Pixel And Layer',    'Callback', {@obj.openCounterAtPoint_Callback, 0, 1});
        end
		function makePlots(obj)
			N = length(obj.colors);

            f = obj.ax.Parent;

            while ~isa(f, 'matlab.ui.Figure')
                f = f.Parent;
            end

            menu = uicontextmenu('Parent', f);  % Menu needs a figure as parent.
            obj.menus.menu = menu;
            obj.makeMenu

			hold(obj.ax, 'on');
            obj.ax.ButtonDownFcn = @obj.figureClickCallback;
            obj.ax.DataAspectRatioMode = 'manual';
            obj.ax.DataAspectRatio = [1 1 1];
            obj.ax.BoxStyle = 'full';
            obj.ax.Box = 'on';
            obj.ax.UIContextMenu = menu;
            obj.ax.XGrid = 'on';
            obj.ax.YGrid = 'on';
            obj.ax.Layer = 'top';
%             obj.ax.TickDir = 'both';
%             disableDefaultInteractivity(obj.ax)
%             obj.ax.Toolbar.Visible = 'off';
%             obj.ax.XMinorTick = 'on';
%             obj.ax.YMinorTick = 'on';


            if true % darkmode
                obj.ax.Color = [.1 .15 .1];
                obj.ax.GridColor = [.9 .95 .9];
            end

            if true % axis thickness
                obj.ax.LineWidth = 1;
                obj.ax.FontSize = 12;
            end


			defaultvis = 'off';

            % Make image
            obj.img = image(obj.ax, 'CData', NaN,...
                                    'Visible', defaultvis,...
                                    'XDataMode', 'manual',...
                                    'YDataMode', 'manual',...
                                    'ButtonDownFcn', @obj.figureClickCallback,...
                                    'UIContextMenu', menu);

            for ii = 1:N
                % Make texts
                obj.txt{ii} = text(.5, .5 - .15*(ii-(N+1)/2.), 1, 'NaN',...
                                                            'Parent', obj.ax,...
                                                            'HorizontalAlignment', 'center',...
                                                            'Units', 'normalized',....
                                                            'Color', obj.colors{ii}/2,...
                                                            'FontSize', 64,...
                                                            'Visible', defaultvis,...
                                                            'PickableParts', 'none');

                % Make plots
                obj.plt{ii} = plot(obj.ax, [0 ii], [0 1], 	'Color', [obj.colors{ii} obj.alpha],... % 'MarkerEdgeWidth', 0,... % 'MarkerEdgeColor', obj.colors{ii},...
                                                            'MarkerFaceColor', obj.colors{ii},...
                                                            'LineWidth', obj.linewidth,...
                                                            'Visible', defaultvis,...
                                                            'PickableParts', 'none');
            end

			assert(length(obj.pnames) == 3)
			assert(length(obj.pnames) == length(obj.pcolors))
			assert(length(obj.pnames) == length(obj.plinewidth))
			assert(length(obj.pnames) == length(obj.plinetype))

            for ii = 1:length(obj.plinewidth)
                % Make pointer `+`s
				obj.ptr{ii} = plot(obj.ax,...
                                    [NaN, NaN, NaN, NaN, NaN],...
                                    [NaN, NaN, NaN, NaN, NaN],...
                                    obj.plinetype{ii},...
									'Color', obj.pcolors{ii},...
									'LineWidth', obj.plinewidth(ii),...
									'Visible', 'on',...
                                    'PickableParts', 'none');
            end
        end
		function makePanel(obj)
			obj.panel.panel.Visible = 'off';
			obj.panel.panel.Units = 'characters';

            if obj.panel.panel.Position(4) < 30
                obj.panel.panel.Position(4) = 30;
                obj.panel.panel.Position(3) = obj.panel.panel.Position(3)*.75;
            end

			width = obj.panel.panel.InnerPosition(3);
			height = obj.panel.panel.InnerPosition(4);
			padding = .4;
			ch = 1.4;
            lw = 4;
            
            if isempty(obj.s.controller) || isvalid(obj.s.controller)
                obj.s.controller = Base.SweepController(obj.s, obj.panel.panel);
                height = height - 2;
            end

			numaxes = length(obj.axesDisplayedNames);

			aph = ch*numaxes + padding*(numaxes+4);
			apanel = uipanel(obj.panel.panel, 			'Title', 'Slice Axes',....
														'Units', 'characters',...
														'Position', [padding, height-aph-padding, width-2*padding, aph]);

			N = length(obj.displayAxesObjects);
			aNames = {};

            for ii = 1:N
                aNames{end+1} = obj.displayAxesObjects{ii}.get_label(); %#ok<AGROW>
            end

			for ii = 1:numaxes
				uicontrol(apanel, 								'Style', 'text',...
																'String', [' ' upper(obj.axesDisplayedNames{ii}) ': '],...
																'HorizontalAlignment', 'right',...
																'Units', 'characters',...
                                                                'Tooltip', ['Set the ' upper(obj.axesDisplayedNames{ii}) ' axis of the slice to a chosen dimension.'],...
																'Position', [padding, aph-padding-(ch+padding)*ii-.3-1.5*padding, lw, ch]);

				obj.panel.axesDisplayed(ii) = uicontrol(apanel, 'Style', 'popupmenu',...
																'String', aNames,...
																'Value', obj.axesDisplayed(ii),...
																'UserData', ii,...
																'HorizontalAlignment', 'left',...
																'Units', 'characters',...
																'Position', [2*padding+lw, aph-padding-(ch+padding)*ii-1.5*padding, width-7*padding-lw, ch],...
																'Callback', @obj.axeschanged_Callback);
			end

			% For each color value, make
% 			N = length(obj.colors);

			obj.panel.tabgroup = uitabgroup('Parent', obj.panel.panel,...
											'Units', 'characters',...
											'Position', [0, 0, width, height - aph - 2*padding],...
                                            'SelectionChangedFcn', @obj.tabchanged_Callback);

			obj.panel.panel.Visible = 'on';
        end
        
        function delete(obj)
            delete(obj.listeners.data)
            delete(obj.listeners.x)
            delete(obj.listeners.y)
%             delete(obj.ax)
%             delete(obj.panel)
            delete(obj.txt)
            delete(obj.plt)
            delete(obj.img)
            delete(obj.ptr)
        end
    end

    methods                                         % uimenu callbacks (when right-clicking on the graph)
        function figureClickCallback(obj, ~, evt)
            if evt.Button == 1  % Left click
                if (now - obj.lastclick)*24*60*60 < obj.doubleclicksec
                    obj.lastclick = 0;
                    
                    x = evt.IntersectionPoint(1);
                    y = evt.IntersectionPoint(2);
                    
                    obj.setPtr(2, [x, y]);
                    
                    obj.gotoPostion_Callback(0, 0, 1, 0);
                else
                    obj.lastclick = now;
                end
                
                obj.setPtr(1, [NaN, NaN]);
                obj.setPtr(2, [NaN, NaN]);
            end
            
            if evt.Button == 3  % Right click
                x = evt.IntersectionPoint(1);
                y = evt.IntersectionPoint(2);

                [isNone, enabled] = obj.isNoneEnabled();
                
                switch sum(~isNone)
                    case 1  % 1D
                        if obj.axesDisplayed(1) == 1
                            ylist = (obj.plt{1}.YData - y) .* (obj.plt{1}.YData - y);
                            xi = find(ylist == min(ylist), 1);
                            xp = obj.plt{1}.YData(xi);
                            
                            obj.setPtr(1, [NaN, xp]);
                            obj.setPtr(2, [NaN, y]);
                            x = y;
                        else
                            xlist = (obj.plt{1}.XData - x) .* (obj.plt{1}.XData - x);
                            xi = find(xlist == min(xlist), 1);
                            xp = obj.plt{1}.XData(xi);
                            
                            obj.setPtr(1, [xp, NaN]);
                            obj.setPtr(2, [x, NaN]);
                        end

                        unitsX = obj.displayAxesObjects{obj.axesDisplayed(~isNone)}.unit;

                        for ii = 1:length(obj.names)
                            valr = NaN;

                            if enabled(ii)
                                if isNone(2)
                                    valr = obj.plt{ii}.YData(xi);
                                else
                                    valr = obj.plt{ii}.XData(xi);
                                end
                            end

                            obj.ptrData(1) = valr;
                            
                            if obj.sp{ii}.I > 0
                                unitsC = obj.s.measurements(obj.sp{ii}.I).unit;
                            else
                                unitsC = '~~~~';
                            end

                            if isnan(valr)
                                obj.menus.ctsMenu(ii).Label = [obj.names{ii} ': ~~~~ ' unitsC];
                            else
                                obj.menus.ctsMenu(ii).Label = [obj.names{ii}  ': ' num2str(valr, 4) ' ' unitsC];
                            end
                        end

                        obj.menus.posMenu.Label = ['Position: ' num2str(x, 4)  ' ' unitsX];
                        obj.menus.indMenu.Label = ['Index: '    num2str(xi)];
                        obj.menus.pixMenu.Label = ['Pixel: '    num2str(xp, 4) ' ' unitsX];
                    case 2  % 2D
                        xlist = (obj.img.XData - x) .* (obj.img.XData - x);
                        ylist = (obj.img.YData - y) .* (obj.img.YData - y);
                        xi = find(xlist == min(xlist), 1);
                        yi = find(ylist == min(ylist), 1);
                        xp = obj.img.XData(xi);
                        yp = obj.img.YData(yi);

                        obj.setPtr(1, [xp, yp]);
                        obj.setPtr(2, [x, y]);

                        unitsX = obj.displayAxesObjects{obj.axesDisplayed(1)}.unit;
                        unitsY = obj.displayAxesObjects{obj.axesDisplayed(2)}.unit;

                        if size(obj.img.CData, 3) == 1
                            obj.ptrData(1:3) = NaN;

                            x = 1:3;
                            ii = x(enabled);

                            val = obj.img.CData(yi, xi) * (obj.sp{ii}.M - obj.sp{ii}.m) + obj.sp{ii}.m;
                            
                            val

                            obj.ptrData(ii) = val;

                            for jj = 1:length(obj.names)
                                if obj.sp{jj}.I > 0
                                    unitsC = obj.s.measurements(obj.sp{jj}.I).unit;
                                else
                                    unitsC = '~~~~';
                                end

                                if ii ~= jj
                                    obj.menus.ctsMenu(jj).Label = [obj.names{jj} ': ~~~~ ' unitsC];
                                else
                                    obj.menus.ctsMenu(jj).Label = [obj.names{jj}  ': ' num2str(val, 4) ' ' unitsC];
                                end
                            end
                        else
                            for ii = 1:length(obj.names)
                                val = NaN;

                                if enabled(ii)
                                    val = obj.img.CData(yi, xi, ii) * (obj.sp{ii}.M - obj.sp{ii}.m) + obj.sp{ii}.m;
                                end

                                obj.ptrData(ii) = val;

                                if obj.sp{ii}.I > 0
                                    unitsC = obj.s.measurements(obj.sp{ii}.I).unit;
                                else
                                    unitsC = '~~~~';
                                end

                                if isnan(val)
                                    obj.menus.ctsMenu(ii).Label = [obj.names{ii} ': ~~~~ ' unitsC];
                                else
                                    obj.menus.ctsMenu(ii).Label = [obj.names{ii}  ': ' num2str(val, 4) ' ' unitsC];
                                end
                            end
                        end

                        obj.menus.posMenu.Label = ['Position: [ ' num2str(x, 4)  ' ' unitsX ', ' num2str(y, 4)  ' ' unitsY ' ]'];
                        obj.menus.indMenu.Label = ['Index: [ '    num2str(xi)               ', ' num2str(yi)               ' ]'];
                        obj.menus.pixMenu.Label = ['Pixel: [ '    num2str(xp, 4) ' ' unitsX ', ' num2str(yp, 4) ' ' unitsY ' ]'];
                    otherwise
                        for ii = 1:length(obj.names)
                            obj.ptrData(1) = NaN;
                            
                            if obj.sp{ii}.I > 0
                                unitsC = obj.s.measurements(obj.sp{ii}.I).unit;
                            else
                                unitsC = '~~~~';
                            end
                            
                            obj.menus.ctsMenu(ii).Label = [obj.names{ii} ': ~~~~ ' unitsC];
                        end

                        obj.menus.posMenu.Label = 'Position: ~~~~ ~~~~';
                        obj.menus.indMenu.Label = 'Index: ~~~~';
                        obj.menus.pixMenu.Label = 'Pixel: ~~~~ ~~~~';
                end
            end
        end
        function gotoPostion_Callback(obj, ~, ~, isPos, shouldGotoLayer)    % Menu option to goto a position. See below for function of isSel and shouldGotoLayer.
            x = obj.ptr{1+isPos}.XData(5);
            y = obj.ptr{1+isPos}.YData(1);
            
            if ~isnan(x) && ~obj.displayAxesObjects{obj.axesDisplayed(1)}.display_only
                obj.displayAxesObjects{obj.axesDisplayed(1)}.writ(x);
            end
            if ~isnan(y) && ~obj.displayAxesObjects{obj.axesDisplayed(2)}.display_only
                obj.displayAxesObjects{obj.axesDisplayed(2)}.writ(y);
            end

            if shouldGotoLayer  % If the use wants to goto the current layer also...
                error('NotImplemented');
%                 for ii = 1:length(obj.displayAxesObjects)
%                     if      obj.data.r.plotMode == 1 && ~any(obj.data.r.l.layer{ii} == [1 2])
%                         scan = obj.data.r.l.scans{ii};
%                         obj.data.r.a.a{ii}.goto(scan(obj.data.d.l.layer{ii} - 2));
%                     elseif  obj.data.r.plotMode == 1 && ~any(obj.data.r.l.layer{ii} == [1 2 3])
%                         scan = obj.data.r.l.scans{ii};
%                         obj.data.r.a.a{ii}.goto(scan(obj.data.d.l.layer{ii} - 3));
%                     end
%                 end
            end
        end
        function minmax_Callback(obj, ~, ~, isMax)                          % Menu option to set the minimum or maximum to value of the selected pixel.
            if ~isnan(obj.ptrData(1))
                obj.sp{1}.normAuto = false;     % Only red for now...
                if isMax
                    obj.sp{1}.M = obj.ptrData(1);
                    if obj.sp{1}.m > obj.ptrData(1)
                        obj.sp{1}.m = obj.sp{1}.M - 1;
                    end
                    obj.datachanged_Callback(0,0);     % Change this, don't need to reprocess, only scale...
                else
                    obj.sp{1}.m = obj.ptrData(1);
                    if obj.sp{1}.M < obj.ptrData(1)
                        obj.sp{1}.M = obj.sp{1}.m + 1;
                    end
                    obj.datachanged_Callback(0,0);     % Change this, don't need to reprocess, only scale...
                end
            end
        end
        function normalizeSlice_Callback(obj, ~, ~, isSlice)	% Add GB!
            for ii = 1:3
                obj.sp{ii}.normAll = isSlice;
            end
            obj.normalize(true);
            obj.datachanged_Callback();
        end
        function normalize_Callback(obj, ~, ~)	% Add GB!
            obj.normalize(true);
            obj.datachanged_Callback();
        end
    end

	methods                                         % 
        function datachanged_Callback(obj, src, evt)
            if ~isempty(evt) && isstruct(evt) && strcmp(evt.Type, 'TimerFcn')
                stop(src)
                delete(src)
            end
            
%             if ~obj.rendering                                                   % If we are not currently rendering,
%                 obj.rendering = true;                                           % Then try to render.
%                 
%                 try
                    if ~isempty(obj.ax) && isvalid(obj.ax)                      % If we still should render,
                        if (now - obj.drawnowLast)*24*60*60 < 1/obj.fpsTarget   % Check to see if rendering now would exceed the fps target.
    %                         disp('datachanged_Callback Postponed');
                            if ~obj.timerposted                                 % If we have not already, remind ourselves to update after fps target has past...
                                t = timer('TimerFcn', @obj.datachanged_Callback, 'ExecutionMode', 'singleShot', 'StartDelay', 2/obj.fpsTarget);
                                obj.timerposted = true;                         % And prevent new timers from being made until this one has been received or enough time has elapsed.
                                start(t);
                            end
%                             obj.rendering = false;
                        else
    %                         disp('datachanged_Callback Accepted');
                            obj.drawnowLast = now;                              % Record that we processed a frame right now.
                            obj.process();                                      % Actually process a frame.
                            drawnow;
                            obj.timerposted = false;                            % Allow the user to post another timer.
%                             obj.rendering = false;
                        end
                    end
%                 catch
%                     disp('datachanged_Callback Error');
%                     obj.rendering = false;
%                 end
%             else
% %                 disp('datachanged_Callback Denied');
%             end
        end
        function [isNone, enabled] = isNoneEnabled(obj)
            isNone = obj.axesDisplayed == 1;

            N = length(obj.sp);

            enabled = false(1,N);

            for ii = 1:N
                enabled(ii) = obj.sp{ii}.enabled;
            end
        end
        function process(obj)
            % Gather useful variables.
            [isNone, enabled] = obj.isNoneEnabled();
            N = length(obj.sp);
            index = 1:N;
            enabledIndex = index(enabled);
            
            % Update the positions of prefs.
            obj.setPtr(3, [NaN, NaN]);  % [NaN, NaN] forces a read of the current position.

            % Process title.
            titledata = '';
            for ii = 1:N
                if enabled(ii)
                    obj.sp{ii}.process();
                    label = obj.s.measurements(obj.sp{ii}.I).get_label();

                    titledata = [titledata sprintf('\\color[rgb]{%.2f,%.2f,%.2f}%s\\color[rgb]{0,0,0}, ', obj.colors{ii}, label)]; %#ok<AGROW>
                end
            end
            if any(enabled)
                title(obj.ax, titledata(1:end-2));  % Remove last ', ' % , 'interpreter', 'latex'
            else
                title('');
            end

            % Process text which displays during the 0D and 1D modes.
            textduring1D = true;
            if  sum(~isNone) > textduring1D   % Turn text off when it is not needed.
                for ii = index
                    if strcmp(obj.txt{ii}.Visible, 'on')
                        obj.txt{ii}.Visible = 'off';
                    end
                end
            elseif any(enabled)    % 0D & 1D
                jj = 0;
                M = sum(enabled)-1;
                for ii = index
                    if enabled(ii)
                        if sum(~isNone) == 0
                            num = obj.sp{ii}.processed;
                        else
                            num = NaN;
                            
                            if obj.s.flags.isContinuous
                                num = obj.sp{ii}.processed(1);
                            else
                                nonnan = obj.sp{ii}.processed(~isnan(obj.sp{ii}.processed));
                                if length(nonnan) > 0
                                    num = nonnan(end);
                                else
                                    num = NaN;
                                end
                            end
%                             num = obj.sp{ii}.processed(min(obj.s.index, numel(obj.sp{ii}.processed)));
%                             if isnan(num) && obj.s.index > 1
%                                 num = obj.sp{ii}.processed(min(obj.s.index-1, numel(obj.sp{ii}.processed)));
%                             end
                        end
                        obj.txt{ii}.String = num2str(num,'%.4f');
                        
                        obj.txt{ii}.Position(2) = .5 + .2*(M/2-jj);
                        if strcmp(obj.txt{ii}.Visible, 'off')
                            obj.txt{ii}.Visible = 'on';
                        end
                        jj = jj + 1;
                    else
                        if strcmp(obj.txt{ii}.Visible, 'on')
                            obj.txt{ii}.Visible = 'off';
                        end
                    end
                end
            end

            % Process plots which display during 1D mode.
            if sum(~isNone) == 1 && any(enabled)
                for ii = index
                    if enabled(ii)
                        if isNone(2)
                            obj.plt{ii}.XData = obj.displayAxesScans{obj.axesDisplayed(1)};
                            obj.plt{ii}.YData = obj.sp{ii}.processed;
                        else
                            obj.plt{ii}.XData = obj.sp{ii}.processed;
                            obj.plt{ii}.YData = obj.displayAxesScans{obj.axesDisplayed(~isNone)};
                        end

                        obj.plt{ii}.Visible = 'on';
                    else
                        if strcmp(obj.plt{ii}.Visible, 'on')
                            obj.plt{ii}.Visible = 'off';    % Make more efficient
                        end
                    end
                end
                
                obj.updateAxes;
            else
                for ii = index
                    if strcmp(obj.plt{ii}.Visible, 'on')
                        obj.plt{ii}.Visible = 'off';    % Make more efficient
                    end
                end
            end

            % Process images which display during 2D mode.
            if sum(~isNone) == 2 && any(enabled)
                alpha_ = ~isnan(obj.sp{enabledIndex(1)}.processed);

                if sum(enabled) == 1    % If grayscale
                    data = repmat( (obj.sp{enabledIndex(1)}.processed - obj.sp{enabledIndex(1)}.m) / (obj.sp{enabledIndex(1)}.M - obj.sp{enabledIndex(1)}.m), [1 1 3]);

                    obj.img.CData = data;
                    obj.img.AlphaData = alpha_;
                else                    % If color
                    partialpixels = true;

                    for ii = enabledIndex(2:end)
                        if partialpixels
                            alpha_ = alpha_ | ~isnan(obj.sp{ii}.processed);
                        else
                            alpha_ = alpha_ & ~isnan(obj.sp{ii}.processed);%#ok
                        end
                    end

                    expectedDimensions = [length(obj.displayAxesScans{obj.axesDisplayed(2)}), length(obj.displayAxesScans{obj.axesDisplayed(1)})];

                    data = NaN([expectedDimensions 3]);

                    for ii = enabledIndex(enabledIndex <= 3)
                        data(:,:,ii) = (obj.sp{ii}.processed - obj.sp{ii}.m) / (obj.sp{ii}.M - obj.sp{ii}.m);
                    end

                    obj.img.CData = data;
                    obj.img.AlphaData = alpha_;
                end

                realAxes = obj.axesDisplayed(~isNone);

                obj.img.XData = obj.displayAxesScans{realAxes(1)};
                obj.img.YData = obj.displayAxesScans{realAxes(2)};

                obj.img.Visible = 'on';
            else
                if strcmp(obj.img.Visible, 'on')
                    obj.img.Visible = 'off';    % Make more efficient
                end
            end
        end

		function axeschanged_Callback(obj, src, ~)
            obj.setAxis(src.UserData, src.Value)
		end
		function setAxis(obj, axis, to)
			N = length(obj.axesDisplayed);

			assert(axis > 0 && axis <= N)
			L = 1:N;
			alreadyTaken = obj.axesDisplayed == to & L ~= axis;     %

			axesNew = obj.axesDisplayed;
            if to ~= 1                                              % Every display axis except for None cannot be repeated
                assert(sum(alreadyTaken) < 2)
                axesNew(alreadyTaken) = obj.axesDisplayed(axis);    % Thus, if this axis already exists, swap the axis with to.
            end
			axesNew(axis) = to;

            if ~isempty(obj.panel)                                  % 
                c = num2cell(axesNew);
                [obj.panel.axesDisplayed.Value] = c{:};
            end

            axesOld = obj.axesDisplayed;
            obj.axesDisplayed = axesNew;
            
            if ~isempty(obj.ax)
                [isNone, enabled] = obj.isNoneEnabled();
                
                for ii = 1:N
                    scan = obj.displayAxesScans{axesNew(ii)};
                    
                    % Handle axis listeners
                    if ~isempty(obj.listeners.(obj.axesDisplayedNames{ii}))
                        delete(obj.listeners.(obj.axesDisplayedNames{ii}));
                    end
                    if ~isa(obj.displayAxesObjects{axesNew(ii)}, 'Prefs.Time') && ~isa(obj.displayAxesObjects{axesNew(ii)}, 'Prefs.Empty')
                        obj.listeners.(obj.axesDisplayedNames{ii}) = obj.displayAxesObjects{axesNew(ii)}.addlistener( 'PostSet', @(s,e)( obj.setPtr(3, [NaN, NaN]) ) );
                    end

                    if any(~isNone)
                        ds = mean(diff(scan))/2;
                        range = [min(scan), max(scan)] + (sum(~isNone) == 2)*ds*[-1 1];     % Expand the range a bit by ds (half-pixel) to capture the half-pixels on each edge

                        label = obj.displayAxesObjects{axesNew(ii)}.get_label();
                        label = strrep(label, '[um]', '[\mum]');

                        if all(isnan(range))
    %                        range = [0 1];
    %                        label = 'Input Axis TODO'

    %                         range = [obj.sp{1}.m obj.sp{1}.M];                  % Fix RGB!
                            range = [NaN NaN];
                            for jj = 1:length(obj.sp)
                                if enabled(jj)
                                    range(1) = min(range(1), obj.sp{jj}.m);
                                    range(2) = max(range(2), obj.sp{jj}.M);
                                end
                            end

                            if isnan(range)
                                range = [0 1];
                            else
                                range = range + .05*diff(range)*[-1 1];
                            end

                            label = obj.sp{1}.tab.input.String{obj.sp{1}.I+1}; %'Filler' %obj.s.inputs{obj.sp{1}.I}.get_label();
                        end
                    
                        if diff(range) == 0
                            range = range + [-1 1];
                        end
                        ticks = true;
                    else
                        range = [0 1];
                        label = '';
                        ticks = false;
                    end
                        
                    switch ii
                        case 1
                            xlim(obj.ax, range);
                            xlabel(obj.ax, label);
                        case 2
                            ylim(obj.ax, range);
                            ylabel(obj.ax, label);
                        case 3
                            zlim(obj.ax, range);
                            zlabel(obj.ax, label);
                    end
                    
                    if ticks
                        switch ii
                            case 1
                                obj.ax.XTickLabelMode = 'auto';
                            case 2
                                obj.ax.YTickLabelMode = 'auto';
                            case 3
                                obj.ax.ZTickLabelMode = 'auto';
                        end
                    else
                        switch ii
                            case 1
                                obj.ax.XTickLabel = [];
                            case 2
                                obj.ax.YTickLabel = [];
                            case 3
                                obj.ax.ZTickLabel = [];
                        end
                    end
                end
            end

            if ~isempty(obj.ax)
                if N == 2
                    ux = obj.displayAxesObjects{obj.axesDisplayed(1)}.unit; % Fix this for 3D...
                    uy = obj.displayAxesObjects{obj.axesDisplayed(2)}.unit;

                    if strcmp(ux, uy)
                        obj.ax.DataAspectRatioMode = 'manual';
                        obj.ax.DataAspectRatio = [1 1 1];
                    else
                        obj.ax.DataAspectRatioMode = 'auto';
                    end
                else
                    obj.ax.DataAspectRatioMode = 'auto';
                end
            end

            if any(axesOld ~= axesNew)
                for ii = 1:length(obj.plinewidth)
                    obj.setPtr(ii, [NaN, NaN]); % Fix this to save ptr if switch
                end

                for ii = 1:length(obj.names)
                    obj.sp{ii}.I = obj.sp{ii}.I;
                end

                obj.datachanged_Callback(0, 0);
            end
        end
        function updateAxes(obj)
            obj.setAxis(1, obj.axesDisplayed(1));
        end

        function axesvaluechanged_Callback(obj, ~, ~)
            obj.setPtr(obj, 3, [NaN NaN])
        end
		function setPtr(obj, ptr, to) 	% Limited to 1D, 2D
            if isvalid(obj) && isvalid(obj.ptr{ptr})
                assert(length(to) == 2);
                dao = obj.displayAxesObjects(obj.axesDisplayed);

                range = NaN(1,4);

                for ii = 1:length(dao)
                    if dao{ii}.display_only
                        range(2*ii + (-1:0)) = [-1e9 1e9];
                    else
                        range(2*ii + (-1:0)) = [max(dao{ii}.min, -1e9) min(dao{ii}.max, 1e9)];

                        if isnan(to(ii))
                            if ptr == 3
                                if ~dao{ii}.display_only
                                    to(ii) = dao{ii}.read();
%                                     to(ii) = dao{ii}.value;
                                else
                                    to(ii) = NaN;
                                end
                            end
                        end
                    end
                end

                obj.ptr{ptr}.XData = [range(1) range(2) NaN to(1) to(1)];
                obj.ptr{ptr}.YData = [to(2) to(2) NaN range(3) range(4)];
            end
            
%             if isvalid(obj) && ~isvalid(obj.ptr{ptr})
%                 warning('Zombie listener');
%             end
        end

        function ct = currentTab(obj)
            ct = obj.panel.tabgroup.SelectedTab.UserData;
        end
        function tabchanged_Callback(obj, src, ~)
            x = src.SelectedTab.UserData;
            assert(isnumeric(x))
            assert(x > 0 && x <= 3)
            obj.sp{x}.makePanel();
%             obj.sp{x}.I = obj.sp{x}.I;  % Tell it to update.
            obj.sp{x}.normalize(false)
        end
    end
end

function copyLabelToClipboard(src, ~)
    split = strsplit(src.Label, ': ');
    clipboard('copy', split{end});
    disp(['"' split{end} '" copied to clipboard.']);
end
