classdef SuperResScan_CW < Modules.Experiment
    %SuperResScan Scan x and y in active stageManager, running resonant + repump
    %sequence at each point.
    %   This will use the active stageManager to set the position (via the
    %   manager)

    properties(SetObservable,GetObservable)
      numberOfScans = 1;
      set_points = 1;
        x_points = Prefs.String('0','units','um','help_text','Valid MATLAB expression evaluating to list of x points to scan.','set','set_points');
        y_points = Prefs.String('0','units','um','help_text','Valid MATLAB expression evaluating to list of y points to scan.','set','set_points');
    end
    properties
        x = 0; % x positions
        y = 0; % y positions
        sequence; %for keeping same sequence from step to step
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'x','y'}; %names of variables to be swept
    end
    properties(Access=private)
        stageManager % Add in pre run to be used in BuildPulseSequence
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = SuperResScan_CW()
            obj.prefs = [{'frequency','x_points','y_points'},obj.prefs,{'resLaser','repumpLaser','APD_line','repump_time','res_time','res_offset'}];
            obj.path = 'APD1';
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
         function run( obj,status,managers,ax )
             obj.imagingManager = managers.Imaging;
             for i = 1:obj.numberOfScans
            info = imagingManager.snap();
             end
         end
            function delete(obj)
            delete(obj.listeners)
            delete(obj.WinSpec)
        end
        function abort(obj)
            obj.WinSpec.abort;
        end
        
        function dat = GetData(obj,~,~)
            dat = [];
            if ~isempty(obj.data)
                dat.diamondbase.data_name = 'Spectrum';
                dat.diamondbase.data_type = 'local';
                dat.wavelength = obj.data.x;
                dat.intensity = obj.data.y;
                dat.meta = rmfield(obj.data,{'x','y'});
            end
        end
    end
end
