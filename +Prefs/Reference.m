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
                    pos_list = [];
                    val_list = [];
                    st_list = []; % Standard deviation of each measurement


                    % Set the optimization range to [start_pos - max_range, start_pos + max_range]
                    % The optimization will automatically stop once current value is out of range.
                    max_range = 20*base_step; 
                    max_iteration = 50;
                    min_step = 0.1*base_step; % Optimization will stop if the current step is too short and there is no improvement.
                    
                    fixed_pos = obj.read;
                    sweep_num = 3;
                    % Sweep [-5:5]*base_step to find a starting point of optimization
                    for k = -sweep_num:sweep_num
                        temp_pos = fixed_pos + k*base_step;
                        pos_list(end+1) = temp_pos;
                        obj.writ(temp_pos);
                        [avg, st] = obj.get_avg_val;
                        val_list(end+1) = avg;
                        st_list(end+1) = st;
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
                            fprintf("Optimization position run out of range. Abort.\n");
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
                        pos_list(end+1) = test_pos;
                        val_list(end+1) = avg;
                        st_list(end+1) = st;
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
                    fig = figure;
                    ax = axes;
                    errorbar(ax, pos_list, val_list, st_list, '.');
                    
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
