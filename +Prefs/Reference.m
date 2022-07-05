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
                    target = ms.get_meta_pref('Target');

                    base_step = ms.(sprintf('key_step_%s', lower(obj.name)));
                    step = base_step;
                    success_step = step;
                    % Set the optimization range to [start_pos - max_range, start_pos + max_range]
                    % The optimization will automatically stop once current value is out of range.
                    max_range = 20*base_step; 
                    max_iteration = 50;
                    min_step = 0.1*base_step; % Optimization will stop if the current step is too short and there is no improvement.
                    max_step = 10*base_step;


                    fixed_pos = obj.read;
                    average_time = 5;
                    test_vals = zeros(1, average_time);
                    for k = 1:average_time
                        test_vals(k) = target.read;
                        pause(0.1)
                    end
                    test_val_avg = mean(test_vals);
                    fixed_val = test_val_avg;
                    iteration_num = 0;
                    direction_changed = false; % A flag to record whether the step direction is changed after the previous iteration.
                    exploring = false; % Whether we have reached the (maybe local) maximum value during the optimization.
                    while(optimizing == obj.name)
                        % Use hill climbing to optimize a single axis
                        % Step length is based on key_step_(obj.name).
                        
                        if (abs(fixed_pos + step-start_pos) > max_range)
                            fprintf("Optimization position run out of range. Abort.\n");
                            optimizing = "";
                            src.Value = false;
                            obj.writ(fixed_pos);
                            return;
                        end

                        if (iteration_num > max_iteration)
                            fprintf("Optimization iteration rounds exceed %d. Abort.\n", max_iteration);
                            optimizing = "";
                            src.Value = false;
                            obj.writ(fixed_pos);
                            return;
                        end
                        test_pos = fixed_pos + step;
                        obj.writ(test_pos);
                        for k = 1:average_time
                            test_vals(k) = target.read;
                            pause(0.1)
                        end
                        iteration_num = iteration_num + 1;
                        test_val_avg = mean(test_vals);
                        diff = test_val_avg - fixed_val;
                        fprintf("Optimizing axis %s (%s) it:%d step:%.2e fixed_pos: %.2e fixed_val: %.2e test_pos: %.2e, try_val: %.2e.\n", obj.name, obj.reference.name, iteration_num, step, fixed_pos, fixed_val, test_pos, test_val_avg);

                        if diff > 0 % Is a successful optimization step. Keep moving on this direction.
                            direction_changed = false;
                            if exploring
                                exploring = false;
                                step = base_step;
                            end

                            fixed_val = test_val_avg;
                            fixed_pos = fixed_pos + step;
                            success_step = step;
                        else % Fails to optimize: try another direction or shorten the step length.
                            
                            if direction_changed % If already failed in last iteration, shorten the step length.
                                if exploring
                                    step = step + base_step;
                                else
                                    step = step / 2;
                                end
                                if (abs(step) < min_step)
                                    fprintf("Reach local maximum. Try to expand the step length.\n")
                                    exploring = true;
                                    step = success_step; % Set step to its previous value (latest successful iteration step)
                                end
                                if (abs(step) > max_step)
                                    fprintf("Reach maximum in range [%.2e, %.2e]. Abort.\n", fixed_pos - max_step, fixed_pos + max_step);
                                    obj.writ(fixed_pos);
                                    optimizing = "";
                                    src.Value = false;
                                    return;
                                end
                                direction_changed = false; % Refresh this flag.
                            else % The first time to fail
                                step = -step;
                                direction_changed = true;
                            end
                        end

                    end
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
