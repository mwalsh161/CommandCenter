classdef PulseSequenceSweep_invisible < Modules.Experiment
    %PulseSequenceSweep Superclass to streamline running a pulse sequence
    %many times with a sweep between each set of samples. All averaged data
    %is saved for each nCounterBins (samples are immediately processed to mean and std)
    % Subclasses are responsible to provide:
    %   ps = BuildPulseSequence(index1,index2,...)
    %       number of indices determined by vars
    %       superclass will take care of setting "ps.repeat = obj.samples" to
    %       assure it gets done properly.
    %       Returning the logical false value will be interpretted as
    %       skipping that point in the sequence (leaving a NaN in the data)
    % And optionally:
    %   PreRun(status,managers,ax) -> Useful to make plot and store handle
    %       locally (this is called after obj.data.sumCounts and stdCounts
    %       are intialized to NaN
    %   UpdateRun(status,managers,ax,current_average,index1,index2,...) -> Useful 
    %       to update plot data
    %   PostRun(status,managers,ax) -> Turn locally created equipment off, clean up, etc.
    % NOTE to extend set of prefs, subclasses must extend in constructor.
    %   DO NOT overload the prefs property
    %   
    % The superclass will require a NIDAQ.dev and PulseBlaster.Remote
    %
    % obj.data looks like: max(indices) is 1xlength(vars)
    %   obj.data.sumCounts = NaN([obj.averages,max(indices),obj.nCounterBins]);
    %   obj.data.stdCounts = NaN([obj.averages,max(indices),obj.nCounterBins]);
    
    properties(Constant,Abstract)
        % 1xN Cell array of strings for each sweep (breadth-first traversal)
        % Similar to "prefs", this should reference another property
        % defined by the user and accessible to the superclass
        vars
        % A single integer representing the number of counter bins per
        % pulse sequence. All bins are saved in final array
        nCounterBins
    end
    properties
        prefs = {'averages','samples','pbDriver','NIDAQ_dev'};
    end
    properties(SetObservable,AbortSet)
        averages = 2;     % Number of times to perform entire sweep
        samples = 1000;   % Number of samples at each point in sweep
        NIDAQ_dev = 'None Set';
    end
    properties(GetObservable,SetObservable)
        pbDriver = Prefs.String('None Set','allow_empty',false,'set','set_pbDriver');
    end
    properties(SetAccess=protected,Hidden)
        data = [] % subclasses should not set this; it can be manipulated in GetData if necessary
        meta = [] % Store experimental settings
        abort_request = false; % Flag that will be set to true upon abort. Used in run method.
        pbH;    % Handle to pulseblaster
        nidaqH; % Handle to NIDAQ
    end
    
    methods
        run(obj,status,managers,ax) % Main run method in separate file
        
        function obj = PulseSequenceSweep_invisible()
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function dat = GetData(obj,~,~)
            % Callback for saving methods (note, lots more info in the two managers input!)
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
        
        
        function val = set_pbDriver(obj,val,pref)
           
            try
                if strcmp(val,'None Set') % Short circuit
                    obj.pbH = [];  %obj.pb_IP = val;
                else
                    obj.pbH = eval(val); %#ok<*MCSUP> %modified 11/10/19
                end
            catch err
                obj.pbH = [];
                rethrow(err);
            end
        end
        function set.NIDAQ_dev(obj,val)
            if strcmp(val,'None Set') % Short circuit
                obj.nidaqH = [];
                obj.NIDAQ_dev = val;
            end
            try
                obj.nidaqH = Drivers.NIDAQ.dev.instance(val);
                obj.NIDAQ_dev = val;
            catch err
                obj.nidaqH = [];
                obj.NIDAQ_dev = 'None Set';
                rethrow(err);
            end
        end
        
        %% Subclasses should overload these methods
        function pulseSeq = BuildPulseSequence(obj,varargin)
            error('Not implemented.')
        end
        % Short circuit the following methods [no need to be fatal]
        function PreRun(obj,varargin)
        end
        function UpdateRun(obj,varargin)
        end
        function PostRun(obj,varargin)
        end
    end
end