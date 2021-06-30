classdef SpotFinder < Modules.Experiment
    %SpotFinder Optimises stage position to maximise counts or ODMR signal

    properties(SetObservable,GetObservable,AbortSet)
        Type = Prefs.MultipleChoice('ODMR','allow_empty',false,'choices',{'ODMR','Fluorescence'},'help_text','What type of signal to optimise position with');

        % Fluorescence Prefs
        Exposure = Prefs.Double(100, 'help_text', 'APD exposure time','units', 'ms','min',0);
        APD_line = Prefs.String('APD1','help_text','NIDAQ APD Line');
        APD_Sync_line = Prefs.String('CounterSync','help_text','NIDAQ CounterSync Line');
        Laser = Prefs.ModuleInstance('help_text','Laser to be used for optimisation');

        % ODMR Prefs
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator to be used for optimisation');
        MW_freq = Prefs.Double(2870, 'help_text', 'MW frequency', 'units', 'MHz','min',0);
        MW_Power = Prefs.Double(-30, 'help_text', 'MW power', 'units', 'dBm');
        MW_freq_norm = Prefs.Double(2000, 'help_text', 'MW normalisation frequency. If negative, will turn off MW instead', 'units', 'MHz');

        % Optimisation prefs
        alpha = Prefs.Double(1, 'help_text', 'Nelder-Mead alpha reflection parameter','min',0);
        gamma = Prefs.Double(2, 'help_text', 'Nelder-Mead gamma expansion parameter','min',1);
        rho = Prefs.Double(0.5, 'help_text', 'Nelder-Mead rho contraction parameter','min',0,'max',0.5);
        sigma = Prefs.Double(0.5, 'help_text', 'Nelder-Mead sigma shrink parameter','min',0,'max',1);
        max_iterations = Prefs.Integer(100, 'help_text', 'Maximum number of iterations', 'min', 1);
        tolerance = Prefs.Double(.01, 'help_text','Tolerance criterion for stopping the search. Optimisation will stop when standard deviation of current points falls below this value')
        initical_x_length = Prefs.Double(1,'help_text','Length of initial tetrahedron around initial point','units','um');
        initical_y_length = Prefs.Double(1,'help_text','Width of initial tetrahedron around initial point','units','um');
        initical_z_length = Prefs.Double(1,'help_text','Height of initial tetrahedron around initial point','units','um');

        Stage = Prefs.ModuleInstance('help_text','Stage that will be used to find the spot')
        
    end
    properties
        prefs = {'Type','Exposure','MW_freq','MW_freq_norm','MW_Power','max_iterations','tolerance','initical_x_length','initical_y_length','initical_z_length','alpha','gamma','rho','sigma','APD_line','APD_Sync_line','Laser','SignalGenerator','Stage'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()

        function [x, f] = NelderMead_step(f,x,cost_function, Alpha, Gamma, Rho, Sigma)
            % Takes a list of N values f, a NxD array of corresponding locations in D-dimensinal space, and a cost function handle, and calculates the next location according to the Nedler-Mead minimisation algorithm
            
            [f,I] = sort(f); % sort function values
            x = x(I,:);

            x0 = mean(x(1:end-1,:),1); % centroid

            % Check reflected 
            xr = x0 + Alpha*(x0-x(end,:));
            fr = cost_function(xr);

            if f(1)<=fr && fr<f(end-1)
                x(end,:) = xr;
                f(end) = fr;
                return
            end
            if fr<f(1)
                % Check expanded point
                xe = x0 + Gamma*(xr-x0);
                fe = cost_function(xe);
                
                if fe < fr
                    x(end,:) = xe;
                    f(end) = fe;
                    return
                else
                    x(end,:) = xr;
                    f(end) = fr;
                    return
                end
            end

            % Check contracted point
            xc = x0 + Rho*(x(end,1)-x0);
            fc = cost_function(xc);

            if fc < f(end)
                x(end,:) = xc;
                f(end) = fc;
                return
            end
            
            % Shrink points
            for i = 2:size(x,1)
                x(i,:) = x(1,:) + Sigma*(x(i,:)-x(1,:));
                f(i) = cost_function(x(i,:));
            end
                        
        end
    end
    methods(Access=private)
        function obj = SpotFinder()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function f = find_cost(obj, x, ctr)
            % Moves stage to position and finds cost function at that position. If invert, take negative of output so that minimisation works properly
            obj.Stage.move(x(1), x(2), x(3));
            obj.waitUntilStopped;
            
            if nargin<4
                invert = false;
            end

            switch obj.Type
                case 'ODMR'
                    % Normalisation
                    if obj.MW_freq_norm > 0
                        obj.SignalGenerator.MWFrequency = obj.MW_freq_norm*1e6;
                        normalisation = ctr.singleShot(obj.Exposure, 1);
                    else
                        obj.SignalGenerator.off;
                        normalisation =  ctr.singleShot(obj.Exposure, 1);
                        obj.SignalGenerator.on;
                    end

                    % signal
                    obj.SignalGenerator.MWFrequency = obj.MW_freq*1e6;
                    signal = ctr.singleShot(obj.Exposure, 1);

                    f = signal/normalisation;

                case 'Fluorescence'
                    f =  -ctr.singleShot(obj.Exposure, 1);
                otherwise
                    error("%s type of spot finding not implemented", obj.Type)
            end
        end

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
    end
end
