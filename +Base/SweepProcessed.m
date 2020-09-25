classdef SweepProcessed < handle

	properties (SetObservable, AbortSet, SetAccess=private)
		processed = [];
	end

	properties (SetAccess=private)
		s = [];             % Parent scan of type `Base.Sweep`
		v = [];             % Parent viewer of type `Base.SweepViewer`
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
        normShrink = true;  % Whether min and max should shrink to size when normalized, or if they should only expand.

		slice = {};
		sliceDefault = {};

		sliceOptions = [];
		sliceOptionsDefault = [];
        
        listeners = struct();
	end

	methods
		function obj = SweepProcessed(s, v, x)
			obj.s = s;
			obj.v = v;
			obj.x = x;
            
			L = obj.s.ndims() + sum(obj.s.measurementDimensions())

            obj.sliceDefault =      num2cell(ones(1, L));
			obj.sliceDefault(:) =   {':'};
            obj.slice =             num2cell(ones(1, L));
			obj.slice(:) =          {':'};
            obj.sliceOptionsDefault =   2*ones(1, L);           % Default option is 2
            obj.sliceOptions =          2*ones(1, L);           % Default option is 2
            
            obj.sliceOptions(1) = -1;
            if L > 1
                obj.sliceOptions(2) = -2;
            end

			if ~isempty(obj.v.panel) && ~isempty(obj.v.panel.tabgroup) %#ok<*ALIGN>
				obj.makePanel();
                obj.v.panel.tabgroup.SelectedTab = obj.tab.tab;
            end
            
%             obj.v.displayAxesMeasNum
            
%             so = obj.sliceOptions;

% 			if obj.x > max(obj.v.displayAxesMeasNum)
            obj.v.displayAxesMeasNum
			if obj.x > max(abs(obj.v.displayAxesMeasNum))
				obj.I = 0;
            else
				obj.I = x;
            end
            
%             prop = findprop(obj, 'processed');
%             obj.listeners.processed = event.proplistener(obj, prop, 'PostSet', @obj.dataChanged_Callback);

			obj.process();
        end
        
        function makePanel(obj)
			if ~isempty(obj.tab)
				return
			end

			padding = .4;
			ch = 1.4;

			% Tab construction
			obj.tab.tab = uitab('Parent', obj.v.panel.tabgroup, 'Title', obj.v.names{obj.x}, 'UserData', obj.x);

			obj.tab.tab.Units = 'characters';
			width = obj.tab.tab.InnerPosition(3);
			height = obj.tab.tab.InnerPosition(4)-1.5*ch;

			% Input selector
			MM = length(obj.s.measurements_);
			iNames = {'None [none]'};

			for ii = 1:MM
                labels = obj.s.measurements_{ii}.getLabels();
                sd = obj.s.measurements_{ii}.subdata();
                for jj = 1:length(sd)
                    iNames{end+1} = labels.(sd{jj});%#ok
                end
            end

            lw = 6.5;
            ew = 15;

			uicontrol(obj.tab.tab, 					'Style', 'text',...
													'String', 'Data: ',...
                                                    'Tooltip', ['Choose a Base.Measurement subdata to display on the ' obj.v.names{obj.x} ' channel.'],...
													'HorizontalAlignment', 'right',...
													'Units', 'characters',...
			 										'Position', [padding, height-padding-(ch+padding)-.3, lw, ch]);

			obj.tab.input = uicontrol(obj.tab.tab, 	'Style', 'popupmenu',...
                                                    'Interruptible', 'off',...
													'String', iNames,...
													'Value', obj.I+1,...
													'HorizontalAlignment', 'left',...
													'Units', 'characters',...
			 										'Position', [2*padding+lw, height-padding-(ch+padding), width-5*padding-ew-lw, ch],...
													'Callback', @obj.setinput_Callback);

			% Enabled checkbox
			obj.tab.enabled = uicontrol(obj.tab.tab,'Style', 'checkbox',...
                                                    'Interruptible', 'off',...
													'String', 'Enabled? ',...
                                                    'Tooltip', ['Enable or disable the ' obj.v.names{obj.x} ' channel.'],...
													'Value', obj.enabled,...
													'HorizontalAlignment', 'left',...
													'Units', 'characters',...
			 										'Position', [width-ew-padding, height-padding-(ch+padding)-.1, ew, ch],...
                                                    'Callback', @obj.setEnabled_Callback);

			% Scalebox
            obj.tab.scale.panel  = uipanel(	'Parent', obj.tab.tab,...
                                            'Units', 'characters',...
                                            'Position', [padding, height-2.8*ch-5.2, width-4*padding, 6.6],...
                                            'Title', 'Scale');
			obj.makeScaleGUI();

			N = obj.s.ndims();
%             sd = obj.s.subdata;

            tw = 30 / (ismac + 1);
            
            base = 4.6;
            
            height = height - .5;

			% Axes
			for ii = 1:N
				levellist = [obj.axisOptions];

                name = obj.s.sdims{ii}.get_label();
                
				uicontrol(obj.tab.tab, 					'Style', 'text',...
														'String', [name ': '],...
														'Tooltip', ['<html>' name 13 obj.s.sdims{ii}.help_text],...
														'HorizontalAlignment', 'right',...
														'Units', 'characters',...
				 										'Position', [padding, height-padding-(base+ii)*(ch+padding)-.2, tw, ch]);

                bw1 = (width-5*padding-tw)/2;
				popuppos = [2*padding+tw-padding, height-padding-(base+ii)*(ch+padding), bw1, ch];
				editpos = [2*padding+tw+bw1, height-padding-(base+ii)*(ch+padding)-.15, bw1-3*padding, ch];

				val = obj.sliceOptions(ii);
                
				str = 'X';
				vis1 = 'on';
				vis2 = 'off';

				if isreal(val) && val < 0
					assert(-val <= length(obj.v.axesDisplayedNames))
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

            mm = 1;
            
            height = height + .5;

			% Input Panels
			for ii = 1:length(obj.s.measurements_)
                meas = obj.s.measurements_{ii};
                sd = meas.subdata();
                dims_ = meas.getDims();
                names_ = meas.getLabels();
                
                for ll = 1:length(sd)                   % For every meas...
                    dims__ = dims_.(sd{ll});
                    Mi = length(dims__);

                    if Mi == 0
                        obj.tab.inputAxesPanel(mm) = uipanel(	'Parent', obj.tab.tab, 'Visible', 'off');
                        delete(obj.tab.inputAxesPanel(mm))
                    else
                        vis = 'off';

                        if mm == obj.I
                            vis = 'on';
                        end

                        obj.tab.inputAxesPanel(mm) = uipanel(	'Parent', obj.tab.tab,...
                                                                'Units', 'characters',...
                                                                'Position', [padding, height-padding-(base+3+N)*(ch+padding), width-4*padding, (Mi+2)*ch],...
                                                                'Title', names_.(sd{ll}),...
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

%                             removesnap = obj.s.inputs{ii}.inputAxes{jj}.display_only;
                            removesnap = dims__{jj}.display_only;

                            levellist = obj.axisOptions(1:(end-removesnap));

                            name = regexprep(dims__{jj}.get_label(), {['^' names_.(sd{ll})]}, {''});

                            uicontrol(obj.tab.inputAxesPanel(mm), 	'Style', 'text',...
                                                                    'String', [name ': '],...
                                                                    'Tooltip', ['<html>' name 13 dims__{jj}.help_text],...
                                                                    'HorizontalAlignment', 'right',...
                                                                    'Units', 'characters',...
                                                                    'Position', [padding, 1*ch-padding-(-Mi+jj)*(ch+padding)-.2, tw, ch]);

                            bw1 = (width-5*padding-tw)/2;
                            y = 1*ch-padding-(-Mi+jj)*(ch+padding);
                            popuppos = [2*padding+tw-2.5*padding, y, bw1, ch];
                            editpos = [2*padding+tw-1.5*padding+bw1, y-.15, bw1-3*padding, ch];

                            obj.tab.axes(kk) = uicontrol(obj.tab.inputAxesPanel(mm), 	'Style', 'popupmenu',...
                                                                                        'String', levellist,...
                                                                                        'Value', obj.sliceOptions(kk),...
                                                                                        'Visible', 'on',...
                                                                                        'UserData', kk,...
                                                                                        'HorizontalAlignment', 'left',...
                                                                                        'Units', 'characters',...
                                                                                        'Position', popuppos,...
                                                                                        'Callback', @obj.updateSliceOptions_Callback);

                            obj.tab.frozen(kk) = uicontrol(obj.tab.inputAxesPanel(mm),  'Style', 'popupmenu',...
                                                                                        'String', {str},...
                                                                                        'Value', 1,...
                                                                                        'Enable', 'off',...
                                                                                        'Visible', vis2,...
                                                                                        'HorizontalAlignment', 'left',...
                                                                                        'Units', 'characters',...
                                                                                        'Position', popuppos);

                            obj.tab.edit(kk) = uicontrol(obj.tab.inputAxesPanel(mm),    'Style', 'edit',...
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
                    mm = mm + 1;
                end
			end

			% obj.tab.Scrollable = 'on';
        end

        function tf = hasUI(obj)
            tf = isempty(obj.tab);
        end

		function process(obj)
%             disp(['processing ' num2str(obj.x)])
            
            if ~obj.I || ~obj.enabled
                return
            end
            
% 			s_ = size(obj.s.data{obj.I});
%             obj.s.measurements
            sd = obj.s.subdata;
			s_ = size(obj.s.data.(sd{obj.I}).dat);

			N = length(s_);
			D = (1:N);

			S.type = '()';
			S.subs = obj.slice;		% num2cell(obj.slice);
			S.subs(obj.sliceOptions <= 0) = {':'};	% Account for X and Y
            
            p = subsref(obj.s.data.(sd{obj.I}).dat, S);
            
%             p
            
%             obj.v.displayAxesMeasNum
            
            relevant = obj.v.displayAxesMeasNum == 0 | obj.v.displayAxesMeasNum == obj.I; % Look for axes which are either global (0) or related to this input (obj.I)
            
            opts = obj.sliceOptions(relevant(2:end))   % Ignore the first axis, which is None
            
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
            
			scandim = obj.sliceOptions < 0;
			
			xy = abs(obj.sliceOptions(scandim));
            
            tmp = obj.processed;
            
            size(p)
			
			if length(xy) == 2 && diff(xy) > 0		% Transpose the data if the viewer order is reversed from the full data order. Only works for 2D; make generic.
% 				new = squeeze(p)';
%                 e = all(obj.processed(:) == squeeze(p)'
                obj.processed = squeeze(p)';
            else
                obj.processed = squeeze(p);
            end
            
%             tic
            tmp2 = obj.processed;
            
            tmp(isnan(tmp)) = Inf;
            tmp2(isnan(tmp2)) = Inf;
            
            s1 = size(tmp);
            s2 = size(tmp2);
            
            if length(s1) ~= length(s2) || ~all(s1 == s2) || ~all(tmp(:) == tmp2(:))
                obj.dataChanged_Callback(0,0);
            end
%             toc
            
%             obj.processed
            
%             obj.dataChanged_Callback(0,0);
        end

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
                        obj.tab.edit(ii).Tooltip = ['Indices: [ ' num2str(indices) ' ] = ' 10 'Values: [ ' num2str(scan(indices)) ' ] '   obj.v.displayAxesObjects{ii+1}.unit];
                        
                        if obj.sliceOptions == length(obj.axisOptions)
                            obj.tab.edit(ii).Tooltip = [obj.tab.edit(ii).Tooltip 10 'The the current real value is ' num2str(obj.v.displayAxesObjects{ii+1}.value) ' ' obj.v.displayAxesObjects{ii+1}.unit 10 'This parameter is set automatically by the ''snap'' option.'];
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
        
        function setinput_Callback(obj, src, ~)
            obj.I = src.Value-1;
        end
		function set.I(obj, I)
			if isempty(I)
				I = obj.I;
			end

			traitors = obj.v.displayAxesMeasNum(obj.v.axesDisplayed) > 0 & obj.v.displayAxesMeasNum(obj.v.axesDisplayed) ~= I;
            
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
                    obj.tab.edit(ii).Visible = obj.sliceOptions(ii) >= 0;
                end

				if obj.I ~= I
                    
                        if obj.I > 0
                            if isvalid(obj.tab.inputAxesPanel(obj.I))
                                obj.tab.inputAxesPanel(obj.I).Visible = 'off';
                            end
                        end

                        if I > 0
                            obj.tab.inputAxesPanel
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

		% Scale panel creation + callbacks
        function makeScaleGUI(obj)
			ch = 1.4;
            y = .2;
            
            obj.tab.scale.panel.Units = 'characters';
            w = obj.tab.scale.panel.Position(3);
            
            p = .5;
            bw = w/5;
            bx = bw-p;
            
            obj.tab.scale.norm =        uicontrol(  'Parent', obj.tab.scale.panel,...
                                                    'Interruptible', 'off',...
                                                    'Style', 'push',...
                                                    'String', 'Normalize',...
                                                    'ToolTip', 'Calculate the min and max of the data and change the limits of view accordingly',...
                                                    'Units', 'characters',...
                                                    'Position', [p y bw+2*p ch],...
                                                    'Callback', @obj.normalize_Callback);
			obj.tab.scale.normAuto =    uicontrol(  'Parent', obj.tab.scale.panel,...
                                                    'Interruptible', 'off',...
                                                    'Style', 'check',...
                                                    'String', 'Auto',... 
                                                    'ToolTip', 'Every time the data is changed, automatically normalize.',...
                                                    'Units', 'characters',...
                                                    'Position', [5*p+1*bx y bw ch],...
                                                    'Value', obj.normAuto,...
                                                    'Callback', @obj.normauto_Callback);
			obj.tab.scale.normShrink =  uicontrol(  'Parent', obj.tab.scale.panel,...
                                                    'Interruptible', 'off',...
                                                    'Style', 'check',...
                                                    'String', 'Shrink',... 
                                                    'ToolTip', 'Shrink the limits of view to fit the data. If false, the bounds will only get larger when the data needs it, and never smaller.',...
                                                    'Units', 'characters',...
                                                    'Position', [2*p+2*bx y bw ch],...
                                                    'Value', obj.normShrink,...
                                                    'Callback', @obj.normshrink_Callback);
			obj.tab.scale.normAll =     uicontrol(  'Parent', obj.tab.scale.panel,...
                                                    'Interruptible', 'off',...
                                                    'Style', 'check',...
                                                    'String', 'By Slice',...
                                                    'ToolTip', 'Normalize via the slice currently in view. If false, min and max are taken from the unsliced data.',...
                                                    'Units', 'characters',...
                                                    'Position', [1*p+3*bx y bw+1 ch],...
                                                    'Value', ~obj.normAll,...
                                                    'Callback', @obj.normall_Callback);
			obj.tab.scale.normPair =    uicontrol(  'Parent', obj.tab.scale.panel,...
                                                    'Interruptible', 'off',...
                                                    'Style', 'check',...
                                                    'String', 'Paired',...
                                                    'ToolTip', 'Whether this is paired with another color channel that has the same units (e.g. R cts and G cts).',...
                                                    'Units', 'characters',...
                                                    'Position', [5*p+4*bx y bw ch],...
                                                    'Value', false,...
                                                    'Enable', 'off');
			
            obj.tab.scale.ax = axes(obj.tab.scale.panel,    'Units', 'Normalized',...
                                                            'Position', [0 0 1 1],...
                                                            'XGrid', 'on',...
                                                            'YGrid', 'on');
            
            obj.tab.scale.ax.Units = 'characters';
            obj.tab.scale.ax.Position(1) = .1;
            obj.tab.scale.ax.Position(3) = obj.tab.scale.ax.Position(3) - .5;
            obj.tab.scale.ax.Position(2) = 2.5;
            obj.tab.scale.ax.Position(4) = obj.tab.scale.ax.Position(4) - 2.5 - .1;
            
            obj.tab.scale.hist = histogram(obj.tab.scale.ax, NaN, 100,... 
                                            'FaceColor', obj.v.colors{obj.x}*.8,...
                                            'EdgeColor', 'none',...
                                            'PickableParts', 'none');
                                        
            obj.tab.scale.ax.XAxis.FontSize = 7;

            menu = uicontextmenu;
            obj.tab.scale.box = images.roi.Rectangle(obj.tab.scale.ax,  'Deletable', false,...
                                                                        'Color', obj.v.colors{obj.x},...
                                                                        'Position', [0, 0, 100, 100],...
                                                                        'FaceSelectable', true,...
                                                                        'UIContextMenu', menu);
            obj.tab.scale.ax.ButtonDownFcn = [];
            obj.tab.scale.ax.Interactions = [];
            
            obj.tab.scale.ax.Toolbar = [];
            disableDefaultInteractivity(obj.tab.scale.ax)
                                                                    
            obj.normAuto = obj.normAuto;
                                                                    
            addlistener(obj.tab.scale.box, 'MovingROI', @obj.scalePositionChange_Callback);
        end
        function scalePositionChange_Callback(obj, ~, evt)
            obj.m = evt.CurrentPosition(1);
            obj.M = evt.CurrentPosition(1) + evt.CurrentPosition(3);
            
            obj.v.process();
        end
		function normall_Callback(obj, ~, ~)
			obj.normAll = ~obj.tab.scale.normAll.Value;
		end
        function set.normAll(obj,normAll)
            obj.normAll = normAll;
            if ~isempty(obj.tab)
%                 obj.v.process();
                obj.normalize(true);
            end
        end
		function normshrink_Callback(obj, ~, ~)
			obj.normShrink = obj.tab.scale.normShrink.Value;
		end
        function set.normShrink(obj,normShrink)
            obj.normShrink = normShrink;
            if ~isempty(obj.tab)
%                 obj.v.process();
                obj.normalize(true);
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
                    
                    obj.v.process();
                    obj.normalize(true);
                else
                    obj.tab.scale.box.InteractionsAllowed = 'all';
                end
                
            end
        end
		function normalize_Callback(obj, ~, ~)
            obj.v.process();
            obj.normalize(true);
        end
        function dataChanged_Callback(obj, ~, ~)
%             disp(['Normalizing ' num2str(obj.x)])
            obj.normalize(false);
        end
		function normalize(obj, shouldForce)
            sd = obj.s.subdata;
            
            if obj.normAll
                m_ = nanmin(obj.s.data.(sd{obj.I}).dat, [], 'all');
                M_ = nanmax(obj.s.data.(sd{obj.I}).dat, [], 'all');
            else
                m_ = nanmin(obj.processed, [], 'all');
                M_ = nanmax(obj.processed, [], 'all');
            end

			if isempty(m_) || isnan(m_)
				m_ = 0;
			end
			if isempty(M_) || isnan(M_)
				M_ = 1;
            end
            
            if m_ == M_
                m_ = m_ - 1;
                M_ = M_ + 1;
            end

			if (obj.normAuto && ~(obj.m == m_ && obj.M == M_)) || shouldForce
                if obj.normShrink   % Should shrink
                    obj.m = m_;
                    obj.M = M_;
                else
                    obj.m = min(obj.m, m_);
                    obj.M = max(obj.M, M_);
                end
                
                if ~obj.v.rendering
                    obj.v.process();
                end
%                 warning('Should obj.v.process()?')
            end

            if obj.v.currentTab() == obj.x
                obj.tab.scale.ax.Visible = 'off';
                    
                if obj.normAll
                    obj.tab.scale.hist.Data = obj.s.data.(sd{obj.I}).dat;
                else
                    obj.tab.scale.hist.Data = obj.processed(:);
                end

                obj.tab.scale.hist.BinMethod = 'scott'; %'auto';

                r_ = M_ - m_;

                m__ = min(m_-r_/5, obj.m);
                M__ = max(M_+r_/5, obj.M);

                r = M__ - m__;
    
                if r == 0
                    r = r + 1;
                end

                if ~isnan(r)
                    top = max(max(obj.tab.scale.hist.Values), 1);

                    obj.tab.scale.box.Position = [obj.m, -top, obj.M - obj.m, 3.2*top];

                    obj.tab.scale.ax.XLim = [m__ - r/5, M__ + r/5];
                    obj.tab.scale.ax.YLim = [0 top*1.2];
                end
                    
                obj.tab.scale.ax.Visible = 'on';
            end
        end
	end
end
