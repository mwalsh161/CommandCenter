classdef ODMR_cameraFreqSweep < Modules.Experiment
    
    properties
        data = [];
        abort_request = false;  % Request flag for abort
        camera
        PB
        laser
        SG
        
        prefs = {'exposure','nImages','startFreq','stopFreq','Camera_PB_line',...
            'RF_power','nAverages','cameraReadTime','runningAverageIndex','pixelX1',...
            'pixelY1','pixelX2','pixelY2','r','stbIndex','throwAwayBgnIndex',...
            'throwAwayEndIndex','reset','fontsize','linewidth'}
    end
    
    properties(SetObservable)
        exposure = 20;%exposure time in ms
        nImages = 100; %number of images to acquire
        startFreq = 2.85e9; %GHz
        stopFreq = 2.89e9; %GHz
        Camera_PB_line = 3; %index from 1
        RF_power = -10; %dbm
        nAverages = inf; %number of averages to acquire
        cameraReadTime  = 4; %ms: time to transfer images to camera 
        stbIndex = 3; %number of index to run to stabalize experiment
        throwAwayBgnIndex = 3; %throw this many images from beginning of experiment away
        throwAwayEndIndex = 3; %throw this many images from end of experiment away
        runningAverageIndex = 5; %number of experiments to loop over in running average
        pixelX1 = 150; %pxl X to select
        pixelY1 = 200; %pxl Y to select
        pixelX2 = 150;
        pixelY2 = 200;
        r = 1; %radius of pxls to sum over
        reset = {'no', 'yes'}
        
        %%plotting preferences
        
        fontsize = 20;
        linewidth = 5;
        
        
    end
    
    properties(Constant)
        q = 1.6*10^-19; %charge of an electron in columbs
    end
    
    methods(Access=private)
        function obj = ODMR_cameraFreqSweep()
            obj.laser = Sources.Green_532Laser.Laser532_PB.instance; %Get laser handle
            obj.SG = Sources.Signal_Generator.RIGOL.RIGOL_none.instance;    %Get signal generator
            
            obj.camera =  Imaging.Camera.AndorEMCCD.instance; % get camera handle
            obj.PB = Drivers.PulseBlaster.Remote.instance('localhost'); %Get pulseblaster handle
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ODMR.ODMR_cameraFreqSweep();
            end
            obj = Object;
            obj.loadPrefs;
        end
    end
    
    methods
     
         function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle = [];
            for index=1:length(modules)
                class_name=class(modules{index});
                num_levels=strsplit(class_name,'.');
                truth_table=contains(num_levels,active_class_to_find);
                if sum(truth_table)>0
                    module_handle=modules{index};
                end
            end
            assert(~isempty(module_handle)&& isvalid(module_handle),['No actice class under ',active_class_to_find,' in CommandCenter as a source!'])
         end
        
        function set.exposure(obj,val)
           assert(isnumeric(val),'exposure must be a number')
           assert(val >= 20, 'minimum exposure is 20 ms')
           obj.exposure = val;
        end
        
        function set.RF_power(obj,val)
           assert(isnumeric(val),'exposure must be a number')
           obj.RF_power = val;
           obj.SG.MWPower = obj.RF_power;
        end
        
        function abort(obj)
            obj.camera.reset;
            obj.SG.off;
            obj.PB.stop;
            obj.laser.off;
        end
        
        
    end
    
end