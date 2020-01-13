classdef ScanViewer < handle

	properties (SetAccess=private)
		s = [];		% Parent scan of type `Base.Scan`

		ax = [];	% MATLAB Axes object where the data will be plotted.
		panel = [];	% Struct containing panel where viewer info will be displayed.

        menus = [];

		sp = {};	% Child processed scans of type `Base.ScanProcessed`.

        listeners = struct('data', [], 'x', [], 'y', []);
	end

	properties (Hidden, SetAccess=private)
		names = 	{'R', 'G', 'B'}                                 % Processed scan settings
		colors = 	{[1 0 0], [0 1 0], [0 0 1]};
		linewidth = 3;
    end

	properties (Constant, Hidden)
		pnames = 		{'selpix', 'selpnt', 'value'};  % Pointer settings
		pcolors = 		{[0.949, 0.250, 0.505], [0.839, 0.478, 0.611], [0.952, 0.466, 0.105]};
		plinewidth = 	[3 2 2];
		plinetype = 	{'o-', 'o--', 'o-'};

% 		pnames = 		{'selpix', 'selpnt', 'target', 'current'};  % Pointer settings
% 		pcolors = 		{[0.949, 0.250, 0.505], [0.839, 0.478, 0.611], [0.952, 0.729, 0.568], [0.952, 0.466, 0.105]};
% 		plinewidth = 	[3 2 3 2];
% 		plinetype = 	{'o-', 'o--', 'o-', 'o-'};
	end

	properties (SetAccess=private)
		txt = {};	% Text `text`s for 0D situations, along with
		plt = {};	% 1D line `plot()`s for data
		img = [];	% 2D image `imagesc()` for data
		ptr = {};	% Cursor location `+` plots
        ptrData = [];
	end

% 	properties (SetAccess=private)
% 		fullAxes;		% cell arrays				% 1xM array containing 1x(N+D) arrays of `Axis` classes, where D is the dimension of the ith input.
% 		fullScans;		% cell arrays				% 1xM array containing 1x(N+D) numeric arrays of the sweep points, where D is the dimension of the ith input.
% 	end

	properties (Hidden, Access=private)
        drawnowLast = 0;
        timerposted = false;
    end
	properties (Constant, Hidden)
        fpsTarget = 5;
    end

	properties (SetObservable, SetAccess=private)
		axesDisplayed = []                          % Which dimensions are selected to be displayed (e.g. which as x, which as y). Integers according to the corresponding index in displayAxesObjects.
    end
	properties (SetAccess=private)
		displayAxesObjects = {}
		displayAxesScans = {}
		displayAxesInputs = [];
	end
	properties (Hidden, Constant)
		axesDisplayedNames = {'x', 'y'};            % Names of the dimensions that can be displayed by the `ScanViewer`
	end

	methods
		function obj = ScanViewer(s_, ax_, varargin)
			obj.ax = ax_;
            obj.ax.Toolbar = [];
			obj.s = s_;

			obj.displayAxesObjects =    obj.s.axes;
			obj.displayAxesScans =      obj.s.scans;

% 			obj.displayAxesObjects =    [{Base.AxisEmpty()} obj.s.axes];
			obj.displayAxesObjects =    [{Prefs.Empty}      obj.s.axes];
			obj.displayAxesScans =      [{NaN} 				obj.s.scans];
			obj.displayAxesInputs = 	[-1                 zeros(1, length(obj.s.scans))];

			for ii = 1:length(obj.s.inputs) %#ok<*ALIGN>
				obj.displayAxesObjects =    [obj.displayAxesObjects obj.s.inputs{ii}.inputAxes];
				obj.displayAxesScans =      [obj.displayAxesScans   obj.s.inputs{ii}.inputScans];
				obj.displayAxesInputs =     [obj.displayAxesInputs  ii*ones(1, length(obj.s.inputs{ii}.inputScans))];
            end

%             obj.displayAxesScans

			A = length(obj.axesDisplayedNames);
			obj.axesDisplayed = (1:A)+1;
			obj.axesDisplayed(obj.axesDisplayed > length(obj.displayAxesObjects)) = 1;
            % obj.axesDisplayed(obj.axesDisplayed == length(obj.displayAxesObjects)+1) = 1;

            obj.ax.Visible = 'off';
			obj.makeDisplay();

%             'here'

			% First, setup the panel.
			if ~isempty(varargin)
				obj.panel.panel = varargin{1};

				obj.panel.tabgroup = [];

% 				if strcmp(obj.panel.panel.Visible, 'on')
                    obj.panel.panel.Visible = 'off';
					obj.makePanel();
% 				end
			end

			N = length(obj.colors);
			for ii = 1:N
				obj.sp{ii} = Base.ScanProcessed(obj.s, obj, ii);
            end
            obj.panel.tabgroup.SelectedTab = obj.sp{1}.tab.tab;

            obj.setAxis(1, obj.axesDisplayed(1))

            prop = findprop(obj.s, 'data');
            obj.listeners.data = event.proplistener(obj.s, prop, 'PostSet', @obj.datachanged_Callback);
%             obj.listeners.prefs =


            obj.ax.Visible = 'on';
            obj.panel.panel.Visible = 'on';
		end

		function makeDisplay(obj)
			N = length(obj.colors);

            f = obj.ax.Parent;

            while ~isa(f,'matlab.ui.Figure')
                f = f.Parent;
            end

            menu = uicontextmenu('Parent', f);  % Menu needs a figure as parent.
            obj.menus.menu = menu;

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
            obj.ax.TickDir = 'both';
            disableDefaultInteractivity(obj.ax)
%             obj.ax.Toolbar.Visible = 'off';
%             obj.ax.XMinorTick = 'on';
%             obj.ax.YMinorTick = 'on';


            if true % darkmode
                obj.ax.Color = [.1 .15 .1];
                obj.ax.GridColor = [.9 .95 .9];
%                 gui.a.XColor = 'white';
%                 gui.a.YColor = 'white';
%                 gui.a.Title.Color = 'white';
%                 gui.df.Color = 'black';
%                 gui.cbar.Color = 'white';
            end

            if true % thickness
                obj.ax.LineWidth = 1;
                obj.ax.FontSize = 12;

%                 gui.cbar.LineWidth = 1;
%                 gui.cbar.FontSize = 15;
%
%                 gui.cbar.Label.LineWidth = 1;
%                 gui.cbar.Label.FontSize = 15;
%
%                 for ii = 1:3
%                     gui.p(ii).LineWidth = 2;
%                     gui.h(ii).LineWidth = 2;
%                 end
            end


			defaultvis = 'off';

            % Make image
%             obj.img = image(obj.ax, 'YDir', 'normal', 'Visible', defaultvis);


            obj.img = image(obj.ax, 'CData', NaN,...
                                    'Visible', defaultvis,...
                                    'XDataMode', 'manual',...
                                    'YDataMode', 'manual',...
                                    'ButtonDownFcn', @obj.figureClickCallback,...
                                    'UIContextMenu', menu);

			for ii = 1:N
				% Make texts
				obj.txt{ii} = text(.5, .5 - .15*(ii-(N+1)/2.), 'NaN',...
                                                                'Parent', obj.ax,...
																'HorizontalAlignment', 'center',...
																'Units', 'normalized',....
																'Color', obj.colors{ii}/1.5,...
																'FontSize', 64,...
																'Visible', defaultvis,...
                                                                'PickableParts', 'none');

				% Make plots
				obj.plt{ii} = plot(obj.ax, [0 ii], [0 1], 	'Color', obj.colors{ii},... % 'MarkerEdgeWidth', 0,... % 'MarkerEdgeColor', obj.colors{ii},...
														    'MarkerFaceColor', obj.colors{ii},...
															'LineWidth', obj.linewidth,...
															'Visible', defaultvis,...
                                                            'PickableParts', 'none');
            end

%             obj.txt
%             obj.plt

			assert(length(obj.pnames) == 3)
			assert(length(obj.pnames) == length(obj.pcolors))
			assert(length(obj.pnames) == length(obj.plinewidth))
			assert(length(obj.pnames) == length(obj.plinetype))

%             obj.ptr

			for ii = 1:length(obj.plinewidth)
				% Make pointer `+`s
% 				p = plot(obj.ax,...
% 									[-1, 1, NaN, 0, 0],...
% 									[0, 0, NaN, -1, 1],...
%                                     obj.plinetype{ii},...
% 									'Color', obj.pcolors{ii},...
% 									'LineWidth', obj.plinewidth(ii),...
% 									'Visible', defaultvis);
%
%                 p

				obj.ptr{ii} = plot(obj.ax,...
                                    [NaN, NaN, NaN, NaN, NaN],...
                                    [NaN, NaN, NaN, NaN, NaN],...
                                    obj.plinetype{ii},...
									'Color', obj.pcolors{ii},...
									'LineWidth', obj.plinewidth(ii),...
									'Visible', 'on',...
                                    'PickableParts', 'none');


% 									[-1, 1, NaN, 0, 0],...
% 									[0, 0, NaN, -1, 1],...


            end

%             obj.ptr

            % Menu Setup --------------------------------------------------------------------------------------------------------------
            obj.menus.ctsMenu(1) = uimenu(menu, 'Label', 'R: ~~~~ --',                  'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{1});
            obj.menus.ctsMenu(2) = uimenu(menu, 'Label', 'G: ~~~~ --',                  'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{2});
            obj.menus.ctsMenu(3) = uimenu(menu, 'Label', 'B: ~~~~ --',                  'Callback', @copyLabelToClipboard, 'ForegroundColor', obj.colors{3}); %, 'Enable', 'off');

            obj.menus.pixMenu = uimenu(menu, 'Label', 'Pixel: [ ~~~~ --, ~~~~ -- ]',    'Callback', @copyLabelToClipboard, 'Separator', 'on'); %, 'Enable', 'off');
            obj.menus.indMenu = uimenu(menu, 'Label', 'Index: [ ~~~~, ~~~~ ]',          'Callback', @copyLabelToClipboard); %, 'Enable', 'off');
            obj.menus.posMenu = uimenu(menu, 'Label', 'Position: [ ~~~~ --, ~~~~ -- ]', 'Callback', @copyLabelToClipboard); %, 'Enable', 'off');

            mGoto = uimenu(menu,                'Label', 'Goto', 'Separator', 'on'); %,     'Callback', {@obj.gotoPostion_Callback, 0, 0});
                mgPos = uimenu(mGoto,           'Label', 'Selected Position',           'Callback', {@obj.gotoPostion_Callback, 0, 0}); %#ok<*NASGU>
                mgPix = uimenu(mGoto,           'Label', 'Selected Pixel',              'Callback', {@obj.gotoPostion_Callback, 1, 0});
                mgPosL= uimenu(mGoto,           'Label', 'Selected Position And Layer', 'Callback', {@obj.gotoPostion_Callback, 0, 1});
                mgPixL= uimenu(mGoto,           'Label', 'Selected Pixel And Layer',    'Callback', {@obj.gotoPostion_Callback, 1, 1});

            mNorm = uimenu(menu,                'Label', 'Normalization'); %,               'Callback',  @obj.normalize_Callback); %, 'Enable', 'off');
                mnMin = uimenu(mNorm,           'Label', 'Set as Minimum',              'Callback', {@obj.minmax_Callback, 0});
                mnMax = uimenu(mNorm,           'Label', 'Set as Maximum',              'Callback', {@obj.minmax_Callback, 1});
                mnNorm= uimenu(mNorm,           'Label', 'Normalize All Layers',        'Callback', {@obj.normalizeSlice_Callback, 0});
                mnNormT=uimenu(mNorm,           'Label', 'Normalize This Layer',        'Callback', {@obj.normalizeSlice_Callback, 1});

            mCount = uimenu(menu,               'Label', 'Counter'); %, 'Enable', 'off');
                mcOpen =    uimenu(mCount,      'Label', 'Open',                        'Callback',  @obj.openCounter_Callback);
                mcOpenAt =  uimenu(mCount,      'Label', 'Open at...');
                    mcoaPos = uimenu(mcOpenAt,  'Label', 'Selected Position',           'Callback', {@obj.openCounterAtPoint_Callback, 1, 0});
                    mcoaPix = uimenu(mcOpenAt,  'Label', 'Selected Pixel',              'Callback', {@obj.openCounterAtPoint_Callback, 0, 0});
                    mcoaPosL= uimenu(mcOpenAt,  'Label', 'Selected Position And Layer', 'Callback', {@obj.openCounterAtPoint_Callback, 1, 1});
                    mcoaPixL= uimenu(mcOpenAt,  'Label', 'Selected Pixel And Layer',    'Callback', {@obj.openCounterAtPoint_Callback, 0, 1});


		end

		function makePanel(obj)
			obj.panel.panel.Visible = 'off';
			obj.panel.panel.Units = 'characters';

            if obj.panel.panel.Position(4) < 50
                obj.panel.panel.Position(4) = 50;
                obj.panel.panel.Position(3) = obj.panel.panel.Position(3)*.75;
            end

			width = obj.panel.panel.InnerPosition(3);
			height = obj.panel.panel.InnerPosition(4);
			padding = .5;
			ch = 1.25;

			numaxes = length(obj.axesDisplayedNames);

			aph = ch*numaxes + padding*(numaxes+2);
			apanel = uipanel(obj.panel.panel, 			'Title', 'Slice Axes',....
														'Units', 'characters',...
														'Position', [padding, height-aph-padding, width-2*padding, aph]);

			N = length(obj.displayAxesObjects);
			aNames = {};

			for ii = 1:N
% 				aNames{end+1} = obj.displayAxesObjects{ii}.nameUnits();
%                 obj.displayAxesObjects{ii}
%                 obj.displayAxesObjects{ii}.get_label()
				aNames{end+1} = obj.displayAxesObjects{ii}.get_label(); %#ok<AGROW>
            end

% 			aNames{end+1} = 'None';

			for ii = 1:numaxes
				uicontrol(apanel, 								'Style', 'text',...
																'String', [' ' upper(obj.axesDisplayedNames{ii}) ': '],...
																'HorizontalAlignment', 'left',...
																'Units', 'characters',...
																'Position', [padding, aph-padding-(ch+padding)*ii, 2*ch, ch]);

				obj.panel.axesDisplayed(ii) = uicontrol(apanel, 'Style', 'popupmenu',...
																'String', aNames,...
																'Value', obj.axesDisplayed(ii),...
																'UserData', ii,...
																'HorizontalAlignment', 'left',...
																'Units', 'characters',...
																'Position', [2*padding+ch, aph-padding-(ch+padding)*ii, width-5*padding-ch, ch],...
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
    end

    methods
        function figureClickCallback(obj, ~, evt)
%             evt.Button
%             evt
            if evt.Button == 3  % Right click
                x = evt.IntersectionPoint(1);
                y = evt.IntersectionPoint(2);

                [isNone, enabled] = obj.isNoneEnabled();

                switch sum(~isNone)
                    case 0  % histogram
                        % Do nothing.
                    case 1  % 1D
                        xlist = (obj.plt{1}.XData - x) .* (obj.plt{1}.XData - x);
                        xi = find(xlist == min(xlist), 1);
                        xp = obj.plt{1}.XData(xi);

%                         unitsX = obj.data.r.l.unit{obj.data.r.l.layer == 1};
%                         unitsX = obj.data.r.l.unit{obj.data.r.l.layer == 1};
                        unitsX = obj.displayAxesObjects{obj.axesDisplayed(~isNone)}.unit;

%                         obj.posL.sel.XData = [x x];
%                         obj.posL.pix.XData = [xp xp];
                        obj.setPtr(1, [xp, xp]);
                        obj.setPtr(2, [x, x]);

                        for ii = 1:length(obj.names)
                            valr = NaN;

                            if enabled(ii)
                                valr = obj.plt{1}.YData(xi);
                            end

                            obj.ptrData(1) = valr;

                            unitsC = 'cts/sec';

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

%                         obj.pos.sel.XData = x;
%                         obj.pos.sel.YData = y;
%                         obj.pos.pix.XData = xp;
%                         obj.pos.pix.YData = yp;

                        obj.setPtr(1, [xp, yp]);
                        obj.setPtr(2, [x, y]);

%                         unitsX = obj.data.r.l.unit{obj.data.r.l.layer == 1};
%                         unitsY = obj.data.r.l.unit{obj.data.r.l.layer == 2};

                        unitsX = obj.displayAxesObjects{obj.axesDisplayed(1)}.units;
                        unitsY = obj.displayAxesObjects{obj.axesDisplayed(2)}.units;

                        if size(obj.img.CData, 3) == 1
                            obj.ptrData(1:3) = NaN;

                            x = 1:3;
                            ii = x(enabled);

                            val = obj.img.CData(yi, xi) * (obj.sp{ii}.M - obj.sp{ii}.m) + obj.sp{ii}.m;

                            obj.ptrData(ii) = val;

                            for jj = 1:length(obj.names)
                                unitsC = 'cts/sec';

                                '�';

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

                                unitsC = 'cts/sec';
    %                             unitsC = '--';

                                if isnan(val)
                                    obj.menus.ctsMenu(ii).Label = [obj.names{ii} ': ~~~~ ' unitsC];
                                else
                                    obj.menus.ctsMenu(ii).Label = [obj.names{ii}  ': ' num2str(val, 4) ' ' unitsC];
                                end
                            end
                        end

                        obj.menus.posMenu.Label = ['Position: [ ' num2str(x, 4)  ' ' unitsX ', ' num2str(y, 4)  ' ' unitsY ' ]'];
                        obj.menus.indMenu.Label = ['Index: [ '    num2str(xi)               ', ' num2str(yi) ' ]'];
                        obj.menus.pixMenu.Label = ['Pixel: [ '    num2str(xp, 4) ' ' unitsX ', ' num2str(yp, 4) ' ' unitsY ' ]'];
                end
            end
        end


        % uimenu callbacks (when right-clicking on the graph)
        function gotoPostion_Callback(obj, ~, ~, isPix, shouldGotoLayer)    % Menu option to goto a position. See below for function of isSel and shouldGotoLayer.
%             if obj.data.r.plotMode == 1 || obj.data.r.plotMode == 2
%                 if obj.data.r.l.type(obj.data.r.l.layer == 1)
%                     warning('Cannot goto an input axis...');
%                 else
%                     axisX = obj.data.r.a.a{obj.data.r.l.layer == 1};
%
%                     if isSel        % If the user wants to go to the selected position
%                         if obj.data.r.plotMode == 1
%                             axisX.goto(obj.posL.sel.XData(1));
%                         else
%                             axisX.goto(obj.pos.sel.XData(1));
%                         end
%                     else            % If the user wants to go to the selected pixel
%                         if obj.data.r.plotMode == 1
%                             axisX.goto(obj.posL.pix.XData(1));
%                         else
%                             axisX.goto(obj.pos.pix.XData(1));
%                         end
%                     end
%                 end
%             end
%
%             if obj.data.r.plotMode == 2
%                 if obj.data.r.l.type(obj.data.r.l.layer == 2)
%                     warning('Cannot goto an input axis...');
%                 else
%                     axisY = obj.data.r.a.a{obj.data.r.l.layer == 2};
%
%                     if isSel        % If the user wants to go to the selected position
%                         axisY.goto(obj.pos.sel.YData(1));
%                     else            % If the user wants to go to the selected pixel
%                         axisY.goto(obj.pos.pix.YData(1));
%                     end
%                 end
%             end

            x = obj.ptr{1+isPix}.XData(5);
            y = obj.ptr{1+isPix}.YData(1);

            if ~isnan(x)
                obj.displayAxesObjects{obj.axesDisplayed(1)}.writ(x);
            end
            if ~isnan(y)
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
                    obj.datachanged_Callback();     % Change this, don't need to reprocess, only scale...
                else
                    obj.sp{1}.m = obj.ptrData(1);
                    obj.datachanged_Callback();     % Change this, don't need to reprocess, only scale...
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
%         function openCounter_Callback(obj, ~, ~)
% %             pixels = max(round(20/gui.data.d.intTimes(gui.r.input)), 10);   % Aim for 20 sec of data. At least 10 pixels
% %             data2 = mcData(mcData.counterConfig(gui.data.d.inputs{gui.r.input}, pixels, gui.data.d.intTimes(gui.r.input)));
% %             mcDataViewer(data2, false)    % And don't show the control window when opening...
%         end
%         function openCounterAtPoint_Callback(obj, ~, ~, isSel, shouldGotoLayer)
% %             gui.gotoPostion_Callback(0, 0, isSel, shouldGotoLayer);
% %             gui.openCounter_Callback(0, 0);
%         end
    end

	methods
        function datachanged_Callback(obj, src, evt)
            if ~isempty(evt) && isstruct(evt) && strcmp(evt.Type, 'TimerFcn')
                stop(src)
                delete(src)
            end

%             obj.ax
            if ~isempty(obj.ax) && isvalid(obj.ax)  % Remove this eventually?
                if (now - obj.drawnowLast) < 1/24/60/60/obj.fpsTarget
                    if ~obj.timerposted         % If a timer has not been sent off to remind us to update...
                        t = timer('TimerFcn', @obj.datachanged_Callback, 'ExecutionMode', 'singleShot', 'StartDelay', 2/obj.fpsTarget);
                        obj.timerposted = true; % And prevent new timers from being made until this one has been received or enough time has elapsed.
                        start(t)
%                         delete(t)
                    end
                else
                    obj.drawnowLast = now;
                    obj.timerposted = false;
                    obj.process();
                end
            end
        end
        function [isNone, enabled] = isNoneEnabled(obj)
            isNone = obj.axesDisplayed == 1;

            N = length(obj.sp);

            enabled = false(1,N);

            for ii = 1:N
                enabled(ii) = obj.sp{ii}.enabled;
            end

%             if all(~enabled)            % If nothing is enabled, construct isNone such that everything is invisible.
%                 isNone(:) = 	false;
%                 isNone(end+1) = false;
%             end
        end
        function process(obj)
            [isNone, enabled] = obj.isNoneEnabled();

            N = length(obj.sp);

            titledata = '';

            for ii = 1:N
                if enabled(ii)
                    obj.sp{ii}.process();
                    label = obj.s.inputs{obj.sp{ii}.I}.get_label();
%                     label = strrep(label, '[', '\[');
%                     label = strrep(label, ']', '\]');
                    titledata = [titledata '\color[rgb]{' num2str(obj.colors{ii} ) '}' label '\color[rgb]{0 0 0}, ']; %#ok<AGROW>
                end
            end

            if any(enabled)
                title(obj.ax, titledata(1:end-2));  % Remove last ', '
            else
                title('');
            end

            index = 1:N;
            enabledIndex = index(enabled);

            textduring1D = false;

            if sum(~isNone) == 0 && any(enabled)    % 0D
                for ii = enabledIndex
                    obj.txt{ii}.String = obj.sp{ii}.processed;
                    obj.txt{ii}.Visible = 'on';
                end
            elseif sum(~isNone) ~= 1 || ~textduring1D
%                 for ii = index
%                     obj.txt{ii}.Visible = 'off';    % Make more efficient
%                 end
                for ii = index
                    if ~strcmp(obj.txt{ii}.Visible, 'off')
                        obj.txt{ii}.Visible = 'off';    % Make more efficient
                    end
                end
            end

            if sum(~isNone) == 1 && any(enabled)    % 1D
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

                        if textduring1D
                            obj.txt{ii}.String = obj.sp{ii}.processed;%#ok
                            obj.txt{ii}.Visible = 'on';
                        end
                    else
                        if ~strcmp(obj.plt{ii}.Visible, 'off')
                            obj.plt{ii}.Visible = 'off';    % Make more efficient
                        end
                    end
                end
            else
                for ii = index
%                     obj.plt{ii}.Visible = 'off';    % Make more efficient
                    if ~strcmp(obj.plt{ii}.Visible, 'off')
                        obj.plt{ii}.Visible = 'off';    % Make more efficient
                    end
                end
            end

            if sum(~isNone) == 2 && any(enabled)    % 2D

%                 empty = NaN(expectedDimensions);

                alpha = ~isnan(obj.sp{enabledIndex(1)}.processed);

%                 sum(enabled)

                if sum(enabled) == 1 && true  % If grayscale
%                     obj
%                     obj.sp{enabledIndex(1)}


                    data = repmat( (obj.sp{enabledIndex(1)}.processed - obj.sp{enabledIndex(1)}.m) / (obj.sp{enabledIndex(1)}.M - obj.sp{enabledIndex(1)}.m), [1 1 3]);

%                     size(data)
%                     size(alpha)

                    obj.img.CData = data;
                    obj.img.AlphaData = alpha;
%                     obj.img.CLim = [0 1];
                else
                    partialpixels = true;

                    for ii = enabledIndex(2:end)
                        if partialpixels
                            alpha = alpha | ~isnan(obj.sp{ii}.processed);
                        else
                            alpha = alpha & ~isnan(obj.sp{ii}.processed);%#ok
                        end
                    end

                    expectedDimensions = [length(obj.displayAxesScans{obj.axesDisplayed(2)}), length(obj.displayAxesScans{obj.axesDisplayed(1)})];

                    data = NaN([expectedDimensions 3]);

%                     enabledIndex

                    for ii = enabledIndex(enabledIndex <= 3)
%                         ii
                        data(:,:,ii) = (obj.sp{ii}.processed - obj.sp{ii}.m) / (obj.sp{ii}.M - obj.sp{ii}.m);
                    end

                    obj.img.CData = data;
                    obj.img.AlphaData = alpha;
                end

                realAxes = obj.axesDisplayed(~isNone);

                obj.img.XData = obj.displayAxesScans{realAxes(1)};
                obj.img.YData = obj.displayAxesScans{realAxes(2)};

%                 for ii = enabledIndex
%                     size(obj.sp{ii}.processed)
%
%                     if isNone(2)
%                         obj.plt{ii}.XData = obj.displayAxesScans{obj.axesDisplayed(1)};
%                         obj.plt{ii}.YData = obj.sp{ii}.processed;
%                     else
%                         obj.plt{ii}.XData = obj.sp{ii}.processed;
%                         obj.plt{ii}.YData = obj.displayAxesScans{obj.axesDisplayed(~isNone)};
%                     end

                obj.img.Visible = 'on';
%                 end
            else
%                 obj.img.Visible = 'off';    % Make more efficient

                if ~strcmp(obj.img.Visible, 'off')
                    obj.img.Visible = 'off';    % Make more efficient
                end
            end


            obj.setPtr(3, [NaN, NaN]);

%             if (now - obj.drawnowLast) > 1/24/60/60/obj.fpsTarget
%                 drawnow;
                pause(0.001)
%                 obj.drawnowLast = now;
%             end
        end

		function axeschanged_Callback(obj, src, ~)
            obj.setAxis(src.UserData, src.Value)
		end
		function setAxis(obj, axis, to)
%             axis
%             to

			N = length(obj.axesDisplayed);

			assert(axis > 0 && axis <= N)
			L = 1:N;
			alreadyTaken = obj.axesDisplayed == to & L ~= axis;     %

			axesNew = obj.axesDisplayed;

            if to ~= 1                                              % Every display axis except for None cannot be repeated
                assert(sum(alreadyTaken) < 2)
                axesNew(alreadyTaken) = obj.axesDisplayed(axis);
            end

			axesNew(axis) = to;

			if ~isempty(obj.panel)
                c = num2cell(axesNew);
				[obj.panel.axesDisplayed.Value] = c{:};
            end

            if ~isempty(obj.ax)
                for ii = 1:N
%                     ii
                    scan = obj.displayAxesScans{axesNew(ii)};

%                     obj.listeners.(obj.axesDisplayedNames{ii})

                    if ~isempty(obj.listeners.(obj.axesDisplayedNames{ii}))
                        delete(obj.listeners.(obj.axesDisplayedNames{ii}));
                    end

%                     obj.listeners.(obj.axesDisplayedNames{ii}) = obj.displayAxesObjects{axesNew(ii)}.addlistener('PostSet', @(s,e)(obj.setPtr(3, [NaN, NaN])));


%                     obj.listeners.(obj.axesDisplayedNames{ii})

%                     axesNew(ii)
%                     scan

                    range = [min(scan), max(scan)];
%                     label = obj.displayAxesObjects{axesNew(ii)}.nameUnits();
                    label = obj.displayAxesObjects{axesNew(ii)}.get_label();

                    label = strrep(label, '[um]', '[\mum]');

                    if all(isnan(range))
%                        range = [0 1];
%                        label = 'Input Axis TODO'


                        range = [obj.sp{1}.m obj.sp{1}.M];                  % Fix RGB!
                        label = obj.s.inputs{obj.sp{1}.I}.get_label();
                    end

                    switch ii
                        case 1
                            xlim(obj.ax, range)
                            xlabel(obj.ax, label)
                        case 2
                            ylim(obj.ax, range)
                            ylabel(obj.ax, label)
                        case 3
                            zlim(obj.ax, range)
                            zlabel(obj.ax, label)
                    end
                end
            end

            axesOld = obj.axesDisplayed;
            obj.axesDisplayed = axesNew;

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

        function axesvaluechanged_Callback(obj, ~, ~)
            obj.setPtr(obj, 3, [NaN NaN])
        end
		function setPtr(obj, ptr, to) 	% Limited to 1D, 2D
			assert(length(to) == 2);

% 			atemp = [obj.s.axes {NaN}];
            dao = obj.displayAxesObjects(obj.axesDisplayed);

%             if ptr == 1
%                 obj.displayAxesObjects
%                 obj.axesDisplayed
%
%                 dao
%
%                 dao{1}
%                 dao{2}
%             end

			range = NaN(1,4);

			for ii = 1:length(dao)
				if dao{ii}.display_only
					range(2*ii + (-1:0)) = [-1e9 1e9];
					to(ii) = NaN;
				else
% 					range(2*ii + (-1:0)) = dao{ii}.extRange;
%                     dao
					range(2*ii + (-1:0)) = [dao{ii}.min dao{ii}.max];

					if isnan(to(ii))
						if ptr == 3
%                             if isempty(obj.listeners.x) && isempty(obj.listeners.y) % If we're scanning. Change this!
%                                 vec = obj.s.currentPoint();
%                                 to(ii) =
%                             else
                            if ~dao{ii}.display_only
                                to(ii) = dao{ii}.read();
                            else
                                to(ii) = NaN;
                            end
%                             end
% 						elseif ptr == 4
% 							to(ii) = dao{ii}.value;
						end
					end
				end
            end

%             obj.ptr
%
%             obj.ptr(ptr)
%
%             [range(1) range(2) NaN to(2) to(2)]

% 			[range(1) range(2) NaN to(2) to(2)]
% 			[to(1) to(1) NaN range(3) range(4)]

			obj.ptr{ptr}.XData = [range(1) range(2) NaN to(1) to(1)];
			obj.ptr{ptr}.YData = [to(2) to(2) NaN range(3) range(4)];

%             drawnow;%?

%             obj.datachanged_Callback(0, 0);
        end

        function ct = currentTab(obj)
            ct = obj.panel.tabgroup.SelectedTab.UserData;
%             ct = obj.panel.tabgroup
        end
        function tabchanged_Callback(obj, src, ~)
            x = src.SelectedTab.UserData;
            assert(isnumeric(x))
            assert(x > 0 && x <= 3)
%             obj.sp{x}.I = obj.sp{x}.I;  % Tell it to update.
            obj.sp{x}.normalize(false)
        end
    end
end

function copyLabelToClipboard(src, ~)
    split = strsplit(src.Label, ': ');
    clipboard('copy', split{end});
end
