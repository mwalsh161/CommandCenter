classdef ScanProcessed < handle

	properties (SetAccess=private)
		s = [];		% Parent scan of type `Base.Scan`
		v = [];     % Parent viewer of type `Base.ScanViewer`
	end

	properties (Constant)
		axisOptions = {'sum', 'mean', 'median', 'min', 'max', 'snap'};
	end

	properties (Hidden, SetAccess=private)
		tab = [];           % Tab controlling the settings for this particular viewer

		x = 1;				% Which layer this processed data is (e.g. R = 1 or G = 2 or B = 3)
	end

	properties
		I = 1;				% Input that is being processed.

		enabled = true;     % Whether this processed data is actually displayed as a channel of the plot.
		enabledUI = true;	% Whether everything except for the input selector is enabledUI (used when axes selected above are incompatible with the current input)

		m = 0;				% Minimum of scaling
		M = 0;				% Maximum of scaling
		normAuto = true;	% Whether to automatically normalize the scale.
		normAll = false;	% Whether _all_ the data, or merely the current slice is normalized.

		slice = {};
		sliceDefault = {};

		sliceOptions = [];
		sliceOptionsDefault = [];
	end

	properties (SetObservable, SetAccess=private)
		processed = [];
	end

	methods
		function obj = ScanProcessed(s, v, x)
			obj.s = s;
			obj.v = v;
			obj.x = x;

			L = obj.s.dimension() + length(obj.s.inputDimensions());

            obj.sliceDefault =      num2cell(ones(1, L));
			obj.sliceDefault(:) =   {':'};
            obj.slice =             num2cell(ones(1, L));
			obj.slice(:) =          {':'};
            obj.sliceOptionsDefault =   2*ones(1, L);           % Default option is 2
            obj.sliceOptions =          2*ones(1, L);           % Default option is 2
            
            obj.sliceOptions(1) = -1;
            obj.sliceOptions(2) = -2;

			% obj.options = ones(1, L);

% 			for ii = 1:length(obj.v.axesDisplayed)
% 				if obj.v.axesDisplayed(ii) > 1 && obj.v.axesDisplayed(ii) <= L
% 					obj.slice{obj.v.axesDisplayed(ii)-1} = -ii; % L(ii) + length(obj.axisOptions) + ii;
% 				end
% 			end

			if ~isempty(obj.v.panel) && ~isempty(obj.v.panel.tabgroup) %#ok<*ALIGN>
%                 obj.v.panel.tabgroup
				obj.makePanel();
                obj.v.panel.tabgroup.SelectedTab = obj.tab.tab;
            end

			if obj.x > length(obj.s.inputs)
				obj.I = 0;
            else
				obj.I = x;
            end

			obj.process()
        end
        
        function tf = hasUI(obj)
            tf = isempty(obj.tab);
        end

		function process(obj)
            if ~obj.I || ~obj.enabled
                return
            end
            
			s = size(obj.s.data{obj.I});

			N = length(s);
			D = (1:N);

			S.type = '()';
			S.subs = obj.slice;		% num2cell(obj.slice);
			S.subs(obj.sliceOptions <= 0) = {':'};	% Account for X and Y

            
            % This is handled elswhere.
% 			for xx = X(obj.sliceOptions == 6)		% If the option choice was 'snap'...
% 				if ~isempty(obj.v.displayAxesObjects{xx})
%                     dif = abs(obj.v.displayAxesScans{xx} - obj.v.displayAxesObjects{xx}.value);
%                     
%                     indices = 1:length(obj.v.displayAxesScans{xx});
%                     
% 					S.subs{xx} = min(indices(dif == min(dif)));
% 				else
% 					error();
% 				end
%             end
            
%             q = obj.s.data{obj.I};

%             size(q)
            
            p = subsref(obj.s.data{obj.I}, S);
            
%             size(p)
            
%             obj.v.displayAxesInputs
%             obj.I

            relevant = obj.v.displayAxesInputs == 0 | obj.v.displayAxesInputs == obj.I; % Look for axes which are either global (0) or related to this input (obj.I)
            
            opts = obj.sliceOptions(relevant(2:end));   % Ignore the first axis, which is None
            
            for ii = 1:(length(obj.axisOptions)-1)  % Iterate through the non-snap options
                d = D(opts == ii);
                
                if ~isempty(d)
                    switch ii
                        case 1  % sum
                            p = nansum(p, d);
                        case 2  % mean
                            p = nanmean(p, d);
                        case 3  % median
                            p = nanmedian(p, d);
                        case 4  % min
                            p = nanmin(p, [], d);
                        case 5  % max
                            p = nanmax(p, [], d);
                    end
                    
                    D(opts == ii) = [];
                    opts(opts == ii) = [];
                end
            end

%             if obj.normAuto
%                 obj.normalize(p);
%             end

%             'swish'
% % 
%             size(p)

%             p

%             obj.processed = squeeze(p);
%             obj.processed = p;
            
%             'dish'
%             
%             size(obj.processed)
            
%             if callAbove
%             end
            
%             obj.sliceOptions
            
			scandim = obj.sliceOptions < 0;
            
%             scandim
			
			xy = abs(obj.sliceOptions(scandim));
			
% 			xy
			
			% assert(all(size(obj.processed) == L(scandim)));
			
			if length(xy) == 2 && diff(xy) > 0		% Transpose the data if the viewer order is reversed from the full data order. Only works for 2D; make generic.
				obj.processed = squeeze(p)';
            else
                obj.processed = squeeze(p);
            end
            
            obj.dataChanged_Callback(0,0);
		end

% 		function normalize(obj, p)
%             if isempty(p)
%                 p = obj.processed;
%             end
%             
%             if obj.normAll
%                 obj.m = nanmin(nanmin(p));
%                 obj.M = nanmax(nanmax(p));
%             else
%                 obj.m = nanmin(nanmin(obj.s.data{obj.I}));
%                 obj.M = nanmax(nanmax(obj.s.data{obj.I}));
%             end
%             
%             if isnan(obj.m) && isnan(obj.M)
%                 obj.m = 0;
%                 obj.M = 1;
%             end
%             
%             assert(~(isnan(obj.m) || isnan(obj.M)))
%             
%             if obj.m == obj.M
%                 obj.m = obj.m - .5;
%                 obj.M = obj.M + .5;
%             end
%                 
%             assert(obj.m < obj.M);
%         end
        
%         function updateDisplayAxes()
%             
%         end

        function updateSlice_Callback(obj, src, ~)
%             src
%             obj.slice
%             src.UserData
%             src.Value
%             try
            obj.slice{src.UserData} = src.String;
%             catch err
%                 rethrow(err)
%             end
            obj.v.process();
%             obj.normalize(false);
        end
		function set.slice(obj, slice)
            old = obj.slice;
			obj.slice = slice;
            
            try
                for ii = 1:length(obj.slice)
                    if ~isempty(obj.tab)	% If we have a panel...
                        slice_ = slice{ii};
                        slice_(isspace(slice_)) = [];
                        

                        scan = obj.v.displayAxesScans{ii+1}; %#ok<*MCSUP>
                        indices = 1:length(scan);
                        
                        slice_ = strrep(slice_, 'end', num2str(length(scan)));
                        
%                         slice_

                        if slice_(1) == '=' %|| obj.sliceOptions == length(obj.axisOptions)
                            val = NaN;%#ok
                            if slice_(1) == '='
                                val = eval(slice_(2:end));
                            else
                                val = obj.v.displayAxesObjects{ii+1}.value;
                            end
                            
                            dif = abs(scan - val);
                            indices = 1:length(scan);
                            obj.slice{ii} = min(indices(min(dif) == dif));
                            
                            indices = obj.slice{ii};
                            
                            obj.tab.edit(ii).String = obj.slice{ii};
                        elseif slice_(1) == ':'
                            obj.slice{ii} = ':';
                        elseif isnumeric(slice_)
                            indices = slice_;
                        else
%                             slice_
                            obj.slice{ii} = round(eval(slice_));
                            indices = obj.slice{ii};
%                             tt = 'A fraction of the points are used.';
                        end
                        
                        assert(all(indices > 0 & indices <= length(scan)))

% 
%                         obj.tab.edit(ii).String = obj.slice{ii};
                        obj.tab.edit(ii).Tooltip = ['Indices: [ ' num2str(indices) ' ] = ' 10 'Values: [ ' num2str(scan(indices)) ' ] '   obj.v.displayAxesObjects{ii+1}.units];
                        
                        if obj.sliceOptions == length(obj.axisOptions)
                            obj.tab.edit(ii).Tooltip = [obj.tab.edit(ii).Tooltip 10 'The the current real value is ' num2str(obj.v.displayAxesObjects{ii+1}.value) ' ' obj.v.displayAxesObjects{ii+1}.units 10 'This parameter is set automatically by the ''snap'' option.'];
                        end
                    end
                end
            catch err
                obj.slice = old;
                
                for ii = 1:length(obj.slice)
                    if ~isempty(obj.tab)	% If we have a panel...
                        obj.tab.edit(ii).String = obj.slice{ii};
                    end
                end
                
                rethrow(err)
            end
        end
        
        function updateSliceOptions_Callback(obj, src, ~)
%             src
            obj.sliceOptions(src.UserData) = src.Value;
            obj.v.process();
%             obj.normalize(false);a
        end
		function set.sliceOptions(obj, sliceOptions)
%             assert(all(sliceOptions > 0 & sliceOptions <= obj.axisOptions))
            
            old = obj.sliceOptions;
			obj.sliceOptions = sliceOptions;
            
			if ~isempty(obj.tab)	% If we have a panel...
                for ii = 1:length(obj.sliceOptions)
                    
                    if obj.sliceOptions(ii) == length(obj.axisOptions) % If snap
                        if obj.v.displayAxesObjects{ii+1}.display_only
                            obj.sliceOptions(ii) = old(ii);
                            if obj.sliceOptions(ii) > 0
                                obj.tab.axes(ii).Value = obj.sliceOptions(ii);
                                obj.tab.axes(ii).Visible = 'on';
                            else
                                obj.tab.axes(ii).Value = obj.sliceOptionsDefault(ii);
                                obj.tab.axes(ii).Visible = 'off';
                            end
                            error(['Base.ScanProcessed.set.sliceOptions(): Snap not allowed on display_only prefs.'  10 obj.v.displayAxesObjects{ii+1}.help_text])
                        end
                        
                        obj.sliceDefault{ii} = obj.slice{ii};
                        
                        obj.slice{ii} = ['=' num2str(obj.v.displayAxesObjects{ii+1}.value)];
                        
                        obj.tab.edit(ii).Enable = 'off';
                    else
                        if obj.enabledUI
                            obj.tab.edit(ii).Enable = 'on';
                        end
                    end
                    
%                     obj.slice{ii} = obj.sliceDefault{ii};
                    if obj.sliceOptions(ii) > 0
                        obj.tab.axes(ii).Value = obj.sliceOptions(ii);
                        obj.tab.axes(ii).Visible = 'on';
                    else
%                         obj.tab.axes(ii).Value = obj.sliceOptionsDefault(ii);
                        obj.tab.axes(ii).Visible = 'off';
                    end
%                     obj.tab.axes(ii).Value = obj.sliceOptions(ii);
                end
            end
        end
        
		function set.I(obj, I)
			if isempty(I)
				I = obj.I;
			end

			traitors = obj.v.displayAxesInputs(obj.v.axesDisplayed) > 0 & obj.v.displayAxesInputs(obj.v.axesDisplayed) ~= I;

%             obj.I
%             traitors
            
			if any(traitors)
				obj.enabled = false;
				obj.enabledUI = false;
			else
				obj.enabledUI = true;
			end

			if I == 0
				obj.enabled = false;
				obj.enabledUI = false;
            end

			if ~isempty(obj.tab)	% If we have a panel...
%                 obj.I
%                 I

%                 obj.tab.frozen.Visible
%                 obj.sliceOptions < 0

                for ii = 1:length(obj.sliceOptions)
                    if any(ii+1 == obj.v.axesDisplayed)   % If an axis is a slice axis...
                        indices = 1:length(obj.v.axesDisplayedNames);
                        index = indices(ii+1 == obj.v.axesDisplayed);
                        assert(numel(index) == 1)
                        
                        name = obj.v.axesDisplayedNames{index};
                        obj.tab.frozen(ii).String = {upper(name)};
                        obj.sliceOptions(ii) = -index;
                    elseif obj.sliceOptions(ii) < 0
                        obj.sliceOptions(ii) = obj.sliceOptionsDefault(ii);
                    end
                    
                    obj.tab.frozen(ii).Visible = obj.sliceOptions(ii) < 0;
%                     obj.tab.axes(ii).Visible = obj.sliceOptions(ii) >= 0;
                    obj.tab.edit(ii).Visible = obj.sliceOptions(ii) >= 0;
                end

%                 traitors = obj.v.displayAxesInputs(obj.v.axesDisplayed) > 0 & obj.v.displayAxesInputs(obj.v.axesDisplayed) ~= I;


				if obj.I ~= I
                    
                        if obj.I > 0
                            if isvalid(obj.tab.inputAxesPanel(obj.I))
                                obj.tab.inputAxesPanel(obj.I).Visible = 'off';
                            end
                        end

                        if I > 0
                            if isvalid(obj.tab.inputAxesPanel(I))
                                obj.tab.inputAxesPanel(I).Visible = 'on';
                            end
                        end

                    obj.tab.input.Value = I + 1;
				end
            end

            if I ~= obj.I
                obj.I = I;
                
                if length(obj.v.sp) == 3
                    obj.v.datachanged_Callback(0, 0);
                end
            end
            
            if obj.I == 0 && obj.enabledUI
                obj.enabled = true;
            end

			% obj.process();
        end
        
        function setEnabled_Callback(obj, src, ~)
            obj.enabled = src.Value;
            
			if ~isempty(obj.tab)
                obj.v.datachanged_Callback(0, 0);
            end
        end
        function set.enabled(obj, enabled)
			obj.enabled = enabled;

			if ~isempty(obj.tab)
				obj.tab.enabled.Value = enabled;
%                 'here'
			end
		end
		function set.enabledUI(obj, enabledUI)
			obj.enabledUI = enabledUI;

			if obj.enabled && ~enabledUI
				obj.enabled = false;
			end

			if ~isempty(obj.tab)
                str = 'off';

                if enabledUI
                    str = 'on';
                end
            
				obj.tab.enabled.Enable = str;
                for ii = 1:length(obj.tab.axes)
                    obj.tab.axes(ii).Enable = str;
                    obj.tab.edit(ii).Enable = str;
                end
% 				ChildList = get(obj.tab.scale.panel, 'Children');
% 				set(ChildList, 'Enable', str);
                
                obj.tab.scale.normAuto.Enable = str;
                obj.tab.scale.normAll.Enable = str;
                obj.tab.scale.norm.Enable = str;

%                 obj.tab.scale.ax.Enable

                if ~enabledUI
                    obj.tab.scale.hist.Data = NaN;
%                     obj.tab.scale.hist.NumBins = 100;
                end
			end
        end

        function setinput_Callback(obj, src, ~)
            obj.I = src.Value-1;
        end
        
        function makePanel(obj)
			if ~isempty(obj.tab)
				return
			end

			padding = .5;
			ch = 1.25;

			% Tab constructionn
			obj.tab.tab = uitab('Parent', obj.v.panel.tabgroup, 'Title', obj.v.names{obj.x}, 'UserData', obj.x);

			obj.tab.tab.Units = 'characters';
			width = obj.tab.tab.InnerPosition(3);
			height = obj.tab.tab.InnerPosition(4)-1.5*ch;

			% Input selector
			MM = length(obj.s.inputs);
			iNames = {'None [none]'};

			for ii = 1:MM
				iNames{end+1} = obj.s.inputs{ii}.get_label();%#ok
			end


			uicontrol(obj.tab.tab, 					'Style', 'text',...
													'String', 'Input: ',...
													'HorizontalAlignment', 'left',...
													'Units', 'characters',...
			 										'Position', [padding, height-padding-(ch+padding), 5, ch]);

			obj.tab.input = uicontrol(obj.tab.tab, 	'Style', 'popupmenu',...
													'String', iNames,...
													'Value', obj.I+1,...
													'HorizontalAlignment', 'left',...
													'Units', 'characters',...
			 										'Position', [2*padding+3, height-padding-(ch+padding), width-5*padding-5-7.5, ch],...
													'Callback', @obj.setinput_Callback);

			% Enabled checkbox
			obj.tab.enabled = uicontrol(obj.tab.tab,'Style', 'checkbox',...
													'String', 'Enabled? ',...
													'Value', obj.enabled,...
													'HorizontalAlignment', 'left',...
													'Units', 'characters',...
			 										'Position', [2*padding+3+width-5*padding-5-8, height-padding-(ch+padding), 10, ch],...
                                                    'Callback', @obj.setEnabled_Callback);
% 			 										'Position', [padding, height-padding-2*(ch+padding), 10, ch],...

			% Scalebox
            obj.tab.scale.panel  = uipanel(	'Parent', obj.tab.tab,...
                                            'Units', 'characters',...
                                            'Position', [padding, height-2.8*ch-5, width-2*padding, 6],...
                                            'Title', 'Scale');
			obj.makeScaleGUI();
% 			obj.makeScalePanel();
% 			obj.tab.scale.panel.Units = 'characters';
% 			obj.tab.scale.panel.Position(2) = height-3.4*ch-obj.tab.scale.panel.Position(4);

			N = obj.s.dimension();

            tw = 12;
            
            base = 4.6;

			% Axes
			for ii = 1:N
				levellist = [obj.axisOptions]; %strcat(strread(num2str(obj.s.scans{ii}), '%s')', [' ' obj.s.axes{ii}.extUnits])];

%                 name = obj.s.axes{ii}.nameUnits();
                name = obj.s.axes{ii}.get_label();
                
				uicontrol(obj.tab.tab, 					'Style', 'text',...
														'String', [name ': '],...
														'Tooltip', obj.s.axes{ii}.help_text,...
														'HorizontalAlignment', 'left',...
														'Units', 'characters',...
				 										'Position', [padding, height-padding-(base+ii)*(ch+padding), 12, ch]);

                bw1 = (width-5*padding-tw)/2;
				popuppos = [2*padding+tw-padding, height-padding-(base+ii)*(ch+padding), bw1, ch];
				editpos = [2*padding+tw-padding+bw1, height-padding-(base+ii)*(ch+padding), bw1-3*padding, ch];

				val = obj.sliceOptions(ii);
%                 obj.sliceOptions(ii)
%                 val
                % obj.slice
% 				dif = val - length(levellist);

%                 val
%                 length(levellist)+1
				str = 'X';
				vis1 = 'on';
				vis2 = 'off';

%                 dif

				if isreal(val) && val < 0
					assert(-val <= length(obj.v.axesDisplayedNames))
% 					val = obj.sliceDefault{ii};
					str = upper(obj.v.axesDisplayedNames{-val});
					vis1 = 'off';
					vis2 = 'on';
				end

				obj.tab.axes(ii) = uicontrol(obj.tab.tab, 	'Style', 'popupmenu',...
															'String', levellist,...
															'Value', obj.sliceOptions(ii),...
															'Visible', 'on',...
                                                            'UserData', ii,...
															'HorizontalAlignment', 'left',...
															'Units', 'characters',...
					 										'Position', popuppos,...
                                                            'Callback', @obj.updateSliceOptions_Callback);

				obj.tab.frozen(ii) = uicontrol(obj.tab.tab, 'Style', 'popupmenu',...
															'String', {str},...
															'Value', 1,...
															'Enable', 'off',...
															'Visible', vis2,...
															'HorizontalAlignment', 'left',...
															'Units', 'characters',...
					 										'Position', popuppos);

				obj.tab.edit(ii) = uicontrol(obj.tab.tab,   'Style', 'edit',...
															'String', obj.slice{ii},...
															'Visible', vis1,...
                                                            'UserData', ii,...
															'HorizontalAlignment', 'center',...
															'Units', 'characters',...
					 										'Position', editpos,...
                                                            'Callback', @obj.updateSlice_Callback);
            end

            kk = N + 1;

			% Input Panels
			for ii = 1:length(obj.s.inputs)
				Mi = length(obj.s.inputs{ii}.inputAxes);
                
                if Mi == 0
                    obj.tab.inputAxesPanel(ii) = uipanel(	'Parent', obj.tab.tab, 'Visible', 'off');
                    delete(obj.tab.inputAxesPanel(ii))
                else
                    vis = 'off';

                    if ii == obj.I
                        vis = 'on';
                    end

                    obj.tab.inputAxesPanel(ii) = uipanel(	'Parent', obj.tab.tab,...
                                                            'Units', 'characters',...
                                                            'Position', [padding, height-padding-(base+3+N)*(ch+padding), width-2*padding, (Mi+2)*ch],...
                                                            'Title', obj.s.inputs{ii}.name,...
                                                            'Visible', vis);

                    for jj = 1:Mi
                        val = obj.slice{kk};

                        str = 'X';
                        vis1 = 'on';
                        vis2 = 'off';

                        if isreal(val) && val < 0
                            assert(-val <= length(obj.v.displayAxesNames))
        % 					val = obj.sliceDefault{ii};
                            str = upper(obj.v.displayAxesNames{-val});
                            vis1 = 'off';
                            vis2 = 'on';
                        end

                        removesnap = obj.s.inputs{ii}.inputAxes{jj}.display_only;

                        levellist = obj.axisOptions(1:(end-removesnap)); % strcat(strread(num2str(obj.s.inputs{ii}.inputScans{jj}), '%s')', [' ' obj.s.inputs{ii}.inputAxes{jj}.extUnits])];

    % 					name = regexprep(obj.s.inputs{ii}.inputAxes{jj}.nameUnits(), {['^' obj.s.inputs{ii}.name]}, {''});
                        name = regexprep(obj.s.inputs{ii}.inputAxes{jj}.get_label(), {['^' obj.s.inputs{ii}.name]}, {''});

    %                     name

                        uicontrol(obj.tab.inputAxesPanel(ii), 	'Style', 'text',...
                                                                'String', [name ': '],...
                                                                'Tooltip', obj.s.inputs{ii}.inputAxes{jj}.help_text,...
                                                                'HorizontalAlignment', 'left',...
                                                                'Units', 'characters',...
                                                                'Position', [padding, 1*ch-padding-(-Mi+jj)*(ch+padding), 12, ch]);

                        bw1 = (width-5*padding-tw)/2;
                        y = 1*ch-padding-(-Mi+jj)*(ch+padding);
                        popuppos = [2*padding+tw-2.5*padding, y, bw1, ch];
                        editpos = [2*padding+tw-2.5*padding+bw1, y, bw1-3*padding, ch];

                        obj.tab.axes(kk) = uicontrol(obj.tab.inputAxesPanel(ii), 	'Style', 'popupmenu',...
                                                                                    'String', levellist,...
                                                                                    'Value', obj.sliceOptions(kk),...
                                                                                    'Visible', 'on',...
                                                                                    'UserData', kk,...
                                                                                    'HorizontalAlignment', 'left',...
                                                                                    'Units', 'characters',...
                                                                                    'Position', popuppos,...
                                                                                    'Callback', @obj.updateSliceOptions_Callback);

                        obj.tab.frozen(kk) = uicontrol(obj.tab.inputAxesPanel(ii),  'Style', 'popupmenu',...
                                                                                    'String', {str},...
                                                                                    'Value', 1,...
                                                                                    'Enable', 'off',...
                                                                                    'Visible', vis2,...
                                                                                    'HorizontalAlignment', 'left',...
                                                                                    'Units', 'characters',...
                                                                                    'Position', popuppos);

                        obj.tab.edit(kk) = uicontrol(obj.tab.inputAxesPanel(ii),    'Style', 'edit',...
                                                                                    'String', obj.slice{kk},...
                                                                                    'Visible', vis1,...
                                                                                    'UserData', kk,...
                                                                                    'HorizontalAlignment', 'center',...
                                                                                    'Units', 'characters',...
                                                                                    'Position', editpos,...
                                                                                    'Callback', @obj.updateSlice_Callback);

                        kk = kk + 1;
                    end
                end
			end

			% obj.tab.Scrollable = 'on';
        end

        % Next gen scale GUI
        function makeScaleGUI(obj)
% 			obj.tab.scale.panel = uipanel('Parent', obj.tab.tab, 'Units', 'pixels', 'Position', [1 20 pw+2 psh+2*bh], 'Title', 'Scale');

% 			padding = .5;
			ch = 1.25;
            y = 3.8;
            
            obj.tab.scale.norm =        uicontrol('Parent', obj.tab.scale.panel, 'Style', 'push',  'String', 'Normalize',   'Units', 'characters', 'Position', [.5 y 10 ch], 'Callback', @obj.normalize_Callback);

			obj.tab.scale.normAuto =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'check', 'String', 'Auto',        'Units', 'characters', 'Position', [12 y 10 ch], 'Value', obj.normAuto, 'Callback', @obj.normauto_Callback);
			obj.tab.scale.normAll =     uicontrol('Parent', obj.tab.scale.panel, 'Style', 'check', 'String', 'Slicewise',   'Units', 'characters', 'Position', [20 y 10 ch], 'Value', ~obj.normAll, 'Callback', @obj.normall_Callback);
% 			obj.tab.scale.normPair =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'check', 'String', 'Paired',      'Units', 'characters', 'Position', [30 y 10 ch], 'Value', false);
			
            obj.tab.scale.ax = axes(obj.tab.scale.panel,    'Units', 'Normalized',...
                                                            'Position', [0 0 1 1],...
                                                            'XGrid', 'on',...
                                                            'YGrid', 'on');
            
%             obj.ax.ButtonDownFcn = @obj.figureClickCallback;
%             obj.ax.DataAspectRatioMode = 'manual';
%             obj.ax.BoxStyle = 'full';
%             obj.ax.Box = 'on';
%             obj.ax.UIContextMenu = menu;
%             obj.ax.XGrid = 'on';
%             obj.ax.YGrid = 'on';
%             obj.ax.Layer = 'top';
            
            obj.tab.scale.ax.Units = 'characters';
            obj.tab.scale.ax.Position(2) = 1.3;
            obj.tab.scale.ax.Position(4) = obj.tab.scale.ax.Position(4) - 2.5;
            
            obj.tab.scale.hist = histogram(obj.tab.scale.ax, NaN, 100,... 
                                            'FaceColor', obj.v.colors{obj.x}*.8,...
                                            'EdgeColor', 'none',...
                                            'PickableParts', 'none');%,...
%                                             'BinMethod', 'auto');
                                        
%             obj.tab.scale.box =  patch([0, 0, 100, 100], [-1e5, 1e5, 1e5, -1e5],  obj.v.colors{obj.x},...
%                                             'EdgeColor',  obj.v.colors{obj.x},...
%                                             'FaceAlpha', .05,...
%                                             'Linewidth', 3);

            menu = uicontextmenu;
            obj.tab.scale.box = images.roi.Rectangle(obj.tab.scale.ax,  'Deletable', false,...
                                                                        'Color', obj.v.colors{obj.x},...
                                                                        'Position', [0, 0, 100, 100],...
                                                                        'FaceSelectable', true,...
                                                                        'UIContextMenu', menu);
            obj.tab.scale.ax.ButtonDownFcn = [];
            obj.tab.scale.ax.Interactions = [];
            
%             obj.ax.ButtonDownFcn = @obj.figureClickCallback;
%             obj.tab.scale.ax.Toolbar.Visible = 'off';
            obj.tab.scale.ax.Toolbar = [];
            disableDefaultInteractivity(obj.tab.scale.ax)
                                                                    
            obj.normAuto = obj.normAuto;
                                                                    
            addlistener(obj.tab.scale.box, 'MovingROI', @obj.positionChange_Callback);
        end
        function positionChange_Callback(obj, ~, evt)
            obj.m = evt.CurrentPosition(1);
            obj.M = evt.CurrentPosition(1) + evt.CurrentPosition(3);
            
%             obj.dataChanged_Callback(0,0);
            obj.v.process();
        end
        
		% Scale panel creation + callbacks
		function makeScalePanel(obj)
			pw = 250;           % Panel Width, the width of the side panel

			bp = 5;             % Button Padding
			bw = pw/2 - 2*bp;   % Button Width, the width of a button/object
			bh = 16;            % Button Height, the height of a button/object

			psh = 3.25*bh;         % Scale figure height

			obj.tab.scale.panel = uipanel('Parent', obj.tab.tab, 'Units', 'pixels', 'Position', [1 20 pw+2 psh+2*bh], 'Title', 'Scale');

			obj.tab.scale.minText =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'text',   'String', 'Min:',   'Units', 'pixels', 'Position', [bp,psh,bw/4,bh], 'HorizontalAlignment', 'right');
			obj.tab.scale.minEdit =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'edit',   'String', 0,        'Units', 'pixels', 'Position', [2*bp+bw/4,psh,bw/2,bh]); %, 'Enable', 'Inactive');
			obj.tab.scale.minSlid =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'slider', 'Value', 0,         'Units', 'pixels', 'Position', [3*bp+3*bw/4,psh,5*bw/4,bh], 'Min', 0, 'Max', 2, 'SliderStep', [2/300, 2/30]); % Instert reasoning for 2/3

			obj.tab.scale.maxText =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'text',   'String', 'Max:',   'Units', 'pixels', 'Position', [bp,psh-bh,bw/4,bh], 'HorizontalAlignment', 'right');
			obj.tab.scale.maxEdit =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'edit',   'String', 1,        'Units', 'pixels', 'Position', [2*bp+bw/4,psh-bh,bw/2,bh]); %, 'Enable', 'Inactive');
			obj.tab.scale.maxSlid =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'slider', 'Value', 1,         'Units', 'pixels', 'Position', [3*bp+3*bw/4,psh-bh,5*bw/4,bh], 'Min', 0, 'Max', 2, 'SliderStep', [2/300, 2/30]);

			obj.tab.scale.dataMinText = uicontrol('Parent', obj.tab.scale.panel, 'Style', 'text',  'String', 'Data Min:',  'Units', 'pixels', 'Position', [2*bp+bw,psh-2*bh,bw/2,bh], 'HorizontalAlignment', 'right');
			obj.tab.scale.dataMinEdit = uicontrol('Parent', obj.tab.scale.panel, 'Style', 'edit',  'String', 0,            'Units', 'pixels', 'Position', [3*bp+3*bw/2,psh-2*bh,bw/2,bh], 'Enable', 'Inactive');

			obj.tab.scale.dataMaxText = uicontrol('Parent', obj.tab.scale.panel, 'Style', 'text',  'String', 'Data Max:',  'Units', 'pixels', 'Position', [2*bp+bw,psh-3*bh,bw/2,bh], 'HorizontalAlignment', 'right');
			obj.tab.scale.dataMaxEdit = uicontrol('Parent', obj.tab.scale.panel, 'Style', 'edit',  'String', 1,            'Units', 'pixels', 'Position', [3*bp+3*bw/2,psh-3*bh,bw/2,bh], 'Enable', 'Inactive');

			obj.tab.scale.normAuto =    uicontrol('Parent', obj.tab.scale.panel, 'Style', 'check', 'String', 'Auto', 'Units', 'pixels', 'Position', [bp+.7*bw,psh-3*bh,.4*bw,bh], 'Value', obj.normAuto);
			obj.tab.scale.normAll =     uicontrol('Parent', obj.tab.scale.panel, 'Style', 'check', 'String', 'Slicewise', 'Units', 'pixels', 'Position', [bp,psh-3*bh,.6*bw,bh], 'Value', obj.normAll);
			obj.tab.scale.norm =        uicontrol('Parent', obj.tab.scale.panel, 'Style', 'push',  'String', 'Normalize',      'Units', 'pixels', 'Position', [bp,psh-2*bh,1.1*bw,bh], 'Callback', @obj.normalize_Callback);

			obj.tab.scale.minEdit.Callback = @obj.edit_Callback;
			obj.tab.scale.maxEdit.Callback = @obj.edit_Callback;

			obj.tab.scale.minSlid.Callback = @obj.slider_Callback;
			obj.tab.scale.maxSlid.Callback = @obj.slider_Callback;

			obj.tab.scale.normAuto.Callback = @obj.normauto_Callback;
		end
		function normall_Callback(obj, ~, ~)
			obj.normAll = ~obj.tab.scale.normAll.Value;
		end
        function set.normAll(obj,normAll)
            obj.normAll = normAll;
            if ~isempty(obj.tab)
                obj.normalize(false)
            end
        end
		function normauto_Callback(obj, ~, ~)
			obj.normAuto = obj.tab.scale.normAuto.Value;
        end
        function set.normAuto(obj,normAuto)
            obj.normAuto = normAuto;
            if ~isempty(obj.tab)
                if normAuto
                    obj.tab.scale.box.InteractionsAllowed = 'none';
                else
                    obj.tab.scale.box.InteractionsAllowed = 'all';
                end
                
                obj.normalize(false)
            end
        end
		function edit_Callback(obj, src,~)
			val = str2double(src.String);

			if isnan(val)   % If it's NaN (if str2double didn't work), check if it's an equation
				try
					val = eval(src.String);
				catch err
					display(err.message);
					val = 0;
				end
			end

			if isnan(val)   % If it's still NaN, set to zero
				val = 0;
			end

			switch src
				case obj.tab.scale.minEdit
					obj.tab.scale.minSlid.Value = val;
					obj.slider_Callback(obj.tab.scale.minSlid, 0)
				case obj.tab.scale.maxEdit
					obj.tab.scale.maxSlid.Value = val;
					obj.slider_Callback(obj.tab.scale.maxSlid, 0)
			end
		end
		function normalize_Callback(obj, ~, ~)
            obj.v.process();
            obj.normalize(true)
% 			if ~isnan(str2double(obj.tab.scale.dataMinEdit.String))
% 				obj.tab.scale.minSlid.Max = str2double(obj.tab.scale.dataMinEdit.String);
% 			end
% 			obj.tab.scale.minSlid.Value = obj.tab.scale.minSlid.Max;
% 
% 			if ~isnan(str2double(obj.tab.scale.dataMaxEdit.String))
% 				obj.tab.scale.maxSlid.Max = str2double(obj.tab.scale.dataMaxEdit.String);
% 			end
% 			obj.tab.scale.maxSlid.Value = obj.tab.scale.maxSlid.Max;
% 
% 			obj.slider_Callback(obj.tab.scale.minSlid, -1);
% 			obj.slider_Callback(obj.tab.scale.maxSlid, -1);
		end
		function slider_Callback(obj, src, ~)
			maxMagn = floor(log10(src.Max));

			if src.Value <= 0
				src.Value = 0;
				src.Max = 1e4;

				switch src
					case obj.tab.scale.minSlid
						obj.tab.scale.minEdit.String = 0;
					case obj.tab.scale.maxSlid
						obj.tab.scale.maxEdit.String = 0;
				end
			else
				magn = floor(log10(src.Value));

				str = [num2str(src.Value/(10^magn), '%1.1f') 'e' num2str(magn)];

				switch src
					case obj.tab.scale.minSlid
						obj.tab.scale.minEdit.String = str;
					case obj.tab.scale.maxSlid
						obj.tab.scale.maxEdit.String = str;
				end

				if magn+1 > maxMagn
					switch src
						case obj.tab.scale.minSlid
							obj.tab.scale.minSlid.Max = 1.5*10^(magn+1);
						case obj.tab.scale.maxSlid
							obj.tab.scale.maxSlid.Max = 1.5*10^(magn+1);
					end
				end

				if magn+1 < maxMagn
					switch src
						case obj.tab.scale.minSlid
							obj.tab.scale.minSlid.Max = 1.5*10^(magn+1);
						case obj.tab.scale.maxSlid
							obj.tab.scale.maxSlid.Max = 1.5*10^(magn+1);
					end
				end
			end

			if obj.tab.scale.minSlid.Value > obj.tab.scale.maxSlid.Value
				switch src
					case obj.tab.scale.minSlid
						obj.tab.scale.maxSlid.Value = obj.tab.scale.minSlid.Value;
						if obj.tab.scale.maxSlid.Max < obj.tab.scale.minSlid.Value
							obj.tab.scale.maxSlid.Max = obj.tab.scale.minSlid.Value;
						end
						if obj.tab.scale.maxSlid.Min > obj.tab.scale.minSlid.Value
							obj.tab.scale.maxSlid.Min = obj.tab.scale.minSlid.Value;
						end
						obj.slider_Callback(obj.tab.scale.maxSlid, 0);      % Possible recursion if careless?
					case obj.tab.scale.maxSlid
						obj.tab.scale.minSlid.Value = obj.tab.scale.maxSlid.Value;
						if obj.tab.scale.minSlid.Max < obj.tab.scale.maxSlid.Value
							obj.tab.scale.minSlid.Max = obj.tab.scale.maxSlid.Value;
						end
						if obj.tab.scale.minSlid.Min > obj.tab.scale.maxSlid.Value
							obj.tab.scale.minSlid.Min = obj.tab.scale.maxSlid.Value;
						end
						obj.slider_Callback(obj.tab.scale.minSlid, 0);
				end
			else

			end

			obj.applyScale();
        end
        function dataChanged_Callback(obj, ~, ~)
            obj.normalize(false);
        end
		function normalize(obj, shouldForce)
            if obj.normAll
                m_ = nanmin(obj.s.data{obj.I},[],'all');
                M_ = nanmax(obj.s.data{obj.I},[],'all');
            else
                m_ = nanmin(obj.processed,[],'all');
                M_ = nanmax(obj.processed,[],'all');
            end

			if isempty(m_) || isnan(m_)
				m_ = 0;
			end
			if isempty(M_) || isnan(M_)
				M_ = 1;
            end
            
            if m_ == M_
                m_ = m_ + .5;
                M_ = M_ + .5;
            end
            
%             magn = floor(log10(m_));
%             MAGN = floor(log10(M_));
%             
%             mv = floor(m_/(10^(magn-1)))/10;
%             Mv = ceil(M_/(10^(magn-1)))/10;
%             
%             m_ = mv * (10 ^ magn);
%             M_ = Mv * (10 ^ MAGN);

% 			if m <= 0
% 				str = '0';
% 			else
% 				magn = floor(log10(m));
% 				% str = [num2str(m/(10^magn), '%1.1f') 'e' num2str(magn)];
% 				str = [num2str(floor(m/(10^(magn-1)))/10, '%1.1f') 'e' num2str(magn)];
% 			end
% 
% 			if M <= 0
% 				STR = '0';
% 			else
% 				magn = floor(log10(M));
% 				% STR = [num2str(M/(10^magn), '%1.1f') 'e' num2str(magn)];
% 				STR = [num2str(ceil(M/(10^(magn-1)))/10, '%1.1f') 'e' num2str(magn)];
% 			end
% 
% 			if isnan(str2double(str))
% 				str = '0';
% 			end
% 			if isnan(str2double(STR))
% 				STR = '1';
% 			end
% 
% 			if str2double(STR) < str2double(str)
% 				str = '0';
% 				STR = '1';
% 			end
% 
% 			str0 = obj.tab.scale.dataMinEdit.String;
% 			STR0 = obj.tab.scale.dataMaxEdit.String;
% 
% 			obj.tab.scale.dataMinEdit.String = [num2str(mv, '%1.1f') 'e' num2str(magn)];
% 			obj.tab.scale.dataMaxEdit.String = [num2str(Mv, '%1.1f') 'e' num2str(MAGN)];
            %obj.s.data{obj.I}

			if (obj.normAuto && ~(obj.m == m_ && obj.M == M_)) || shouldForce
                obj.m = m_;
                obj.M = M_;
            end

            if obj.v.currentTab() == obj.x
                obj.tab.scale.ax.Visible = 'off';
                
%                 obj.tab.scale.hist.NumBins = 1;
                    
                if obj.normAll
                    obj.tab.scale.hist.Data = obj.s.data{obj.I};
                else
                    obj.tab.scale.hist.Data = obj.processed(:);
                end

                obj.tab.scale.hist.BinMethod = 'scott';%'auto';

                r_ = M_ - m_;

                m__ = min(m_-r_/5, obj.m);
                M__ = max(M_+r_/5, obj.M);

                r = M__ - m__;
    %             r = M_ - m_;

                if ~isnan(r)
                    
                    obj.tab.scale.box.Position(1) = obj.m;
                    obj.tab.scale.box.Position(3) = obj.M - obj.m;

                    top = max(max(obj.tab.scale.hist.Values), 1);

                    obj.tab.scale.box.Position(2) = -top;
                    obj.tab.scale.box.Position(4) = 3.2*top;

    %                 obj.tab.scale.ax.XLim = [m_ - r/10, M_ + r/10];
                    obj.tab.scale.ax.XLim = [m__ - r/5, M__ + r/5];
                    obj.tab.scale.ax.YLim = [0 top*1.2];
                end
                    
                obj.tab.scale.ax.Visible = 'on';
            end
		end
% 		function applyScale(obj)
% 			m = obj.tab.scale.minSlid.Value;
% 			M = obj.tab.scale.maxSlid.Value;
% 
% 			if m == M
% 				m = m - .001;
% 				M = M + .001;   % Make better?
% 			end
% 
% 			obj.m = m;
% 			obj.M = M;
% 		end
	end
end
