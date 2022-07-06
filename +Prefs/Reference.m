classdef Reference < Base.Pref
    %REFERENCE acts as a pointer to other Prefs. set_reference is used to
    % set which Pref this reference points to. Upon setting a Pref to
    % reference, Prefs.Reference behaves exactly as the target Pref via
    % the GUI or the .read() or .writ() methods. This is especially useful
    % for making modules with general functionality.
    
    properties (Hidden)
        default = [];
        ui = Prefs.Inputs.ReferenceField;
        reference = []; % Prefs.Numeric.empty(1,0);
        
        lsh = [];
        record_array;
    end

    methods
        function obj = Reference(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        
        function tf = isnumeric(obj)
            if isempty(obj.reference)
                tf = false;
            else
                tf = obj.reference.isnumeric();
            end
        end
        
        function tosave = encodeValue(obj, ~) % Ignore the passed data value.
            if isempty(obj.reference)
                tosave = [];
            else
                tosave = obj.reference.encode();
            end
        end
        function [data, obj] = decodeValue(obj, saved)
            if isempty(saved)
                return
            end
            try
                obj.reference = Base.Pref.decode(saved);
                data = obj.reference.read();
            catch err
                warning(err.identifier, '%s', err.message);
                pr = Base.PrefRegister.instance();
                obj.reference = pr.getPref(saved.pref, saved.parent.singleton_id);
                data = obj.reference.read();
            end
            
        end
        
        function obj = set_reference(obj, val)
            if ismember('Prefs.Inputs.LabelControlBasic', superclasses(val.ui)) && ~isa(val, 'Prefs.Reference') && ~ismember('Prefs.Reference', superclasses(val)) && ~isequal(obj.parent, val.parent)
                obj.reference = val;
                obj.readonly = val.readonly;
                obj.parent.set_meta_pref(obj.property_name, obj);

                notify(obj.parent, 'update_settings');
            end
        end
        function obj = set_reference_Callback(obj, src, evt)
            pr = Base.PrefRegister.instance;
            pr.getMenu([], @obj.set_reference);
        end


        function [avg, st] = get_avg_val(obj, average_time, max_std_ratio)
            target = obj.parent.get_meta_pref('Target');
            if ~exist('average_time', 'var')
                average_time = 5;
            end
            if ~exist('max_std_ratio', 'var')
                max_std_ratio = 0.2;
            end
            test_vals = zeros(1, average_time);
            for k = 1:average_time
                test_vals(k) = target.read;
                pause(0.1)
            end
            avg = mean(test_vals);
            st = std(test_vals);
            if abs(st/avg) > max_std_ratio
                % The standart deviation is too large. Retake the measurement.
                average_time = average_time*2;
                test_vals = zeros(1, average_time);
                for k = 1:average_time
                    test_vals(k) = target.read;
                    pause(0.1)
                end
                avg = mean(test_vals);
                st = std(test_vals);
            end
        end

        function obj = optimize_Callback(obj, src, evt)
            ms = obj.parent; % MetaStage
            global optimizing; % How to let different callback functions share a same variable?
            if ~isstring(optimizing) && ~ischar(optimizing)
                optimizing = "";
            end
            if src.Value == true
                if optimizing ~= ""
                    warning("Optimization on %s is already started. Please stop the running optimization to start a new one.", optimizing);
                    src.Value = false;

                else % No optimization process has been started yet.
                    if isempty(obj.parent.get_meta_pref('Target').reference)
                        warning("Reference 'Target' is not set properly. Please set a target to start optimization.");
                        optimizing = "";
                        src.Value = false;
                        return;
                    end
                    if strcmp(ms.get_meta_pref('Target').reference.name, 'count')
                        counter = ms.get_meta_pref('Target').reference.parent;
                        running = counter.running;
                        if ~running
                            counter.start;
                        end
                    end

                    optimizing = obj.name;
                    start_pos = obj.read;
                    


                    base_step = ms.(sprintf('key_step_%s', lower(obj.name)));
                    step = base_step;

                    % Record all tried positions and values
                    obj.record_array = {}
                    record = struct;


                    % Set the optimization range to [start_pos - max_range, start_pos + max_range]
                    % The optimization will automatically stop once current value is out of range.
                    max_range = 20*base_step; 
                    max_iteration = 50;
                    min_step = 0.1*base_step; % Optimization will stop if the current step is too short and there is no improvement.
                    
                    fixed_pos = obj.read;
                    sweep_num = 0;
                    % Sweep [-5:5]*base_step to find a starting point of optimization
                    for k = -sweep_num:sweep_num
                        temp_pos = fixed_pos + k*base_step;
                        obj.writ(temp_pos);
                        [avg, st] = obj.get_avg_val;
                        record.pos = temp_pos;
                        record.val = avg;
                        record.st = st;
                        obj.record_array{end+1} = record;
                    end

                    [max_val, max_k] = max(val_list);
                    fixed_pos = pos_list(max_k); % Set the best position to be the fixed point
                    fixed_val = max_val;
                    % fixed_val = obj.get_avg_val;


                    iteration_num = 0;
                    direction_changed = false; % A flag to record whether the step direction is changed after the previous iteration.
                    while(optimizing == obj.name)
                        % Use hill climbing to optimize a single axis
                        % Step length is based on key_step_(obj.name).
                        
                        if (abs(fixed_pos + step-start_pos) > max_range)
                            fprintf("Optimization position runing out of range. Abort.\n");
                            optimizing = "";
                            src.Value = false;
                            obj.writ(fixed_pos);
                            break;
                        end

                        if (iteration_num > max_iteration)
                            fprintf("Optimization iteration rounds exceed %d. Abort.\n", max_iteration);
                            optimizing = "";
                            src.Value = false;
                            obj.writ(fixed_pos);
                            break;
                        end
                        test_pos = fixed_pos + step;
                        obj.writ(test_pos);
                        [avg, st] = obj.get_avg_val;
                        record.pos = temp_pos;
                        record.val = avg;
                        record.st = st;
                        obj.record_array{end+1} = record;
                        diff = avg - fixed_val;
                        
                        iteration_num = iteration_num + 1;
                        fprintf("Optimizing axis %s (%s) it:%d step:%.2e fixed_pos: %.2e fixed_val: %.2e test_pos: %.2e, try_val: %.2e.\n", obj.name, obj.reference.name, iteration_num, step, fixed_pos, fixed_val, test_pos, avg);

                        if diff > 0 % Is a successful optimization step. Keep moving on this direction.
                            direction_changed = false;
                            fixed_val = avg;
                            fixed_pos = fixed_pos + step;
                        else % Fails to optimize: try another direction or shorten the step length.
                            
                            if direction_changed % If already failed in last iteration, shorten the step length.

                                step = step / 2;
                                if (abs(step) < min_step)
                                    fprintf("Reach local maximum. Abort.\n")
                                    obj.writ(fixed_pos);
                                    optimizing = "";
                                    src.Value = false;
                                    break;
                                end
                                direction_changed = false; % Refresh this flag.
                            else % The first time to fail
                                step = -step;
                                direction_changed = true;
                            end
                        end
                    end % End while loop
                    obj.plot_record(1, 1, obj.name);
                    
                end
            else % src.Value == false
                if obj.name == optimizing
                    optimizing = ""; % to end an optimization
                    fprintf("Optimization of axis %s (%s) is interrupted.\n", obj.name, obj.reference.name);
                else % obj.name ~= optimizing, which should not happen if operated correctly
                    warning("Optimization of axis %s is interrupted by button in %s.\n", optimizing, obj.name);
                    optimizing = "";
                end
            end

        end
        
        function obj = global_optimize_Callback(obj, src, evt)
            ms = obj.parent; % MetaStage
            global optimizing; % How to let different callback functions share a same variable?

            function set_pos(test_pos)
                persistent prev_pos;
                if ~exist("prev_pos", "var") || isempty(prev_pos)
                    prev_pos = start_pos; % To memorize the current position of an axis. If the position is not changed during iteration, there is no need to rewrite (which wastes time)
                end
                for m = 1:3
                    if axis_available(m) == false || test_pos(m) == prev_pos(m)
                        continue;
                    end
                    axis_reference{m}.writ(test_pos(m));
                    prev_pos(m) = test_pos(m);
                end
            end

            function pos = get_pos()
                pos = NaN(1, 3);
                for m = 1:3
                    if axis_available(m)
                        pos(m) = axis_reference{m}.read;
                    end
                end
            end
            if ~isstring(optimizing) && ~ischar(optimizing)
                optimizing = "";
            end
            if src.Value == true
                if optimizing ~= ""
                    warning("Optimization on %s is already started. Please stop the running optimization to start a new one.", optimizing);
                    src.Value = false;

                else % No optimization process has been started yet.
                    optimizing = "Target";
                    if strcmp(ms.get_meta_pref('Target').reference.name, 'count')
                        counter = ms.get_meta_pref('Target').reference.parent;
                        running = counter.running;
                        if ~running
                            counter.start;
                        end
                    end

                    % Record all avalable references
                    
                    axis_name = {'X', 'Y', 'Z'};
                    axis_available = zeros(1, 3);
                    axis_stop = ones(1, 3);
                    axis_reference = cell(1, 3); % {Prefs.Reference()}
                    axis_ref_name = cell(1, 3);

                    base_step = zeros(1, 3);
                    start_pos = NaN(1, 3);
                    for k = 1:3
                        mp = ms.get_meta_pref(axis_name{k});
                        if ~isempty(mp.reference)
                            axis_available(k) = 1;
                            axis_stop(k) = 0;
                            axis_reference{k} = mp;
                            start_pos(k) = mp.read;
                            base_step(k) = ms.(sprintf("key_step_%s", lower(axis_name{k})));
                            axis_ref_name{k} = mp.reference.name;
                        end
                    end
                    step = base_step;
                    obj.record_array = {};
                    optimize_dim = sum(axis_available);
                    
                    [avg, st] = obj.get_avg_val;
                    record = struct;
                    record.pos = start_pos;
                    record.val = avg;
                    record.st = st;
                    obj.record_array{end+1} = record;
                    sweep_num = 0;

                    % Do sweep along all avaliable axes
                    for k = 1:3
                        if axis_available(k) == false
                            continue
                        end
                        for l = -sweep_num:sweep_num
                            if l == 0
                                continue; % This origin point is aready tested
                            end
                            % Assign values
                            temp_pos = start_pos;
                            temp_pos(k) = temp_pos(k) + l*base_step(k);
                            set_pos(temp_pos);

                            [avg, st] = obj.get_avg_val;

                            % Record results
                            record.pos = temp_pos;
                            record.val = avg;
                            record.st = st;
                            obj.record_array{end+1} = record;
                        end
                    end

                    % Find the maximum within the sweep results to be a starting point
                    max_val = 0;
                    for l = length(obj.record_array)
                        record = obj.record_array{l};
                        if record.val >= max_val
                            max_pos = record.pos;
                            max_val = record.val;
                        end
                    end

                    fixed_pos = max_pos;
                    fixed_val = max_val;

                    % Set the optimization range to [start_pos - max_range, start_pos + max_range]
                    % The optimization will automatically stop once current value is out of range.
                    max_range = 20*base_step; 
                    max_iteration = 50;
                    min_step = 0.1*base_step; % Optimization will stop if the current step is too short and there is no improvement.
                    iteration_num = 0;
                    direction_changed = zeros(1, 3);



                    while(optimizing == obj.name)
                        if all(axis_stop)
                            fprintf("No available axis to be optimized. Abort.\n");
                            optimizing = "";
                            src.Value = false;
                            set_pos(fixed_pos);
                            break;
                        end
                        % Use hill climbing to iteratively optimize all axes:
                        % 1) Sweep along all available axes, to find a starting point
                        % 2) Record `direction_changed` for all axes separately. 
                        %   If one trial obtains larger target value, set fixed_pos to this point and clear all `direction_changed` flags. 
                        %   Otherwise, flip the `direction_changed` flag if it is not set or shorten the step length for higher resolution.
                        for k = 1:3
                            if axis_stop(k)
                                continue;
                            end
                            if abs(fixed_pos(k)+step(k)-start_pos(k))>max_range(k)
                                axis_stop(k) = true;
                                fprintf("Optimization position of %s running out of range. Disable this axis.\n");
                                continue;
                            end
                            test_pos = fixed_pos;
                            test_pos(k) = fixed_pos(k)+step(k);
                            set_pos(test_pos);
                            [avg, st] = obj.get_avg_val;
                            record.pos = test_pos;
                            record.val = avg;
                            record.st = st;
                            obj.record_array{end+1} = record;

                            diff = avg-fixed_val;
                            iteration_num = iteration_num + 1;
                            fprintf("Globally optimizing axis %s (%s) it:%d step:%.2e fixed_pos: %.2e fixed_val: %.2e test_pos: %.2e, try_val: %.2e.\n", axis_name{k}, axis_reference{k}.name, iteration_num, step(k), fixed_pos(k), fixed_val, test_pos(k), avg);
                            if diff > 0
                                direction_changed = zeros(1, 3); % Clear all flags
                                fixed_val = avg;
                                fixed_pos = fixed_pos+step;
                                % How to persistently optimize along this axis?
                            else
                                if direction_changed(k)
                                    if abs(step(k)) >= min_step(k)
                                        step(k) = step(k)/2;
                                    end
                                    if all(abs(step) <= min_step)
                                        fprintf("All axes reaches local maximum. Abort.\n");
                                        set_pos(fixed_pos);
                                        optimizing = "";
                                        src.Value = false;
                                        break;
                                    end
                                    direction_changed(k) = false;
                                else
                                    step(k) = -step(k);
                                    direction_changed(k) = true;
                                end
                            end
                        end % End for loop

                    end % End while loop
                    
                    obj.plot_records(optimize_dim, axis_available, axis_ref_name);
                end
            else % src.Value == false
                if obj.name == optimizing
                    optimizing = ""; % to end an optimization
                    fprintf("Optimization of axis %s (%s) is interrupted.\n", obj.name, obj.reference.name);
                else % obj.name ~= optimizing, which should not happen if operated correctly
                    warning("Optimization of axis %s is interrupted by button in %s.\n", optimizing, obj.name);
                    optimizing = "";
                end
            end

        end

        function fig = plot_records(obj, dim, axis_available, axis_name)
            % `axis_available` and `axis_name` should be consistent with the order of obj.record_array{i}.pos
            if ~exist('axis_available', 'var')
                % Which axis is in use
                axis_available = 1;
            end
            fig = figure;
            ax = axis;
            record_dim = sum(~isnan(obj.record_array{1}.pos));
            assert(dim == record_dim, sprintf("Input dimension (%d) is not consistent with recorded position dimension (%d).", length(find(available_axis)), optimize_dim));
            
            switch dim
                case 1
                    n = length(obj.record_array);
                    x = zeros(1, n);
                    val = zeros(1,n);
                    st = zeros(1, n);
                    x_axis = find(axis_available);
                    for k = 1:n
                        record = obj.record_array{k};
                        x(k) = record.pos(x_axis);
                        val(k) = record.val;
                        st(k) = record.st;
                    end
                    fig = figure;
                    ax = axes;
                    errorbar(ax, x, val, st, '.');
                    if exist('axis_name', 'var')
                        ax.XLabel = axis_name(x_axis);
                    end
                    if ~isempty(obj.parent.get_meta_pref('Target').reference)
                        ax.YLabel = obj.parent.get_meta_pref('Target').reference.name;
                    end
                    
                case 2
                    n = length(obj.record_array);
                    x = zeros(1, n);
                    val = zeros(1,n);
                    st = zeros(1, n);
                    [x_axis, y_axis] = find(axis_available);
                    for k = 1:n
                        record = obj.record_array{k};
                        x(k) = record.pos(x_axis);
                        y(k) = record.pos(y_axis);              
                        val(k) = record.val;
                        st(k) = record.st;
                    end
                    fig = figure;
                    % ax = axes;
                    plot3(x, y, val);
                    hold on;
                    plot3([x,x], [y,y], [val-st, val+st], '-');
                    if exist('axis_name', 'var')
                        ax.XLabel = axis_name(x_axis);
                        ax.YLabel = axis_name(y_axis);
                    end
                    if ~isempty(obj.parent.get_meta_pref('Target').reference)
                        ax.ZLabel = obj.parent.get_meta_pref('Target').reference.name;
                    end
                otherwise
                    fprintf("Plotting records of dimision %d is not supported", dim);
            end
        end

        function obj = link_callback(obj,callback)
            % This wraps ui.link_callback; careful overloading
            if ~isempty(obj.reference)
                obj.ui.link_callback({callback, obj.reference});
            end
        end
        
        function [obj,height_px,label_width_px] = make_UI(obj,varargin)
            % This wraps ui.make_UI; careful overloading
            [obj.ui, height_px, label_width_px] = obj.ui.make_UI(obj,varargin{:}, obj.readonly);
            obj.reference = obj.ui.gear.UserData;
        end
        
        % Calls to get and set value are now redirected to the pref that is being referenced.
        function val = get_value(obj, ~)
            if isempty(obj.reference)
                val = NaN;
            else
                val = obj.reference.read();
            end
        end
        function [obj, val] = set_value(obj, val)
            if ~isempty(obj.reference)
                obj.reference.writ(val);
            end
        end
        
        function val = get_ui_value(obj)
            val = obj.ui.get_value();
        end
        function obj = set_ui_value(obj,val)
            if ~isempty(obj.reference)
                obj.ui.set_value(val);
            end
            
        end
        
        function val = read(obj)
            if isempty(obj.reference)
                val = NaN;
            else
                val = obj.reference.read();
            end
        end
        function tf = writ(obj, val)

            if isempty(obj.reference)
                tf = false;
            else
                tf = obj.reference.writ(val);
            end
            if isprop(obj.parent, 'parent') && ~isempty(obj.parent.parent)
                msm = obj.parent.parent; % Handle to the MetaStageManager
                notify(msm, 'updated');
            end
        end
    end
end
