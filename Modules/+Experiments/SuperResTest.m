classdef SuperResTest < Modules.Experiment
    %Spectrum Experimental wrapper for Drivers.WinSpec
    
    properties(SetObservable,AbortSet)
        data
       number_scans = 1;
        prefs = {'number_scans'}; % Not including winspec stuff because it can take a long time!
        show_prefs = {'number_scans'};
    end
    properties(SetAccess=private,Hidden)
        listeners
    end
    methods(Access=private)
        function obj = SuperResTest()

            try
                obj.loadPrefs; % Load prefs should load WinSpec via set.ip
            catch err % Don't need to raise alert here
                if ~strcmp(err.message,'WinSpec not set')
                    rethrow(err)
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SuperResTest();
            end
            obj = Object;
        end
       
    end
    
    methods
        function run( obj,status,managers,ax )
          imagingManager = managers.Imaging;
             for i = 1:obj.number_scans
            info = imagingManager.snap();
            obj.data(i,:,:) = info.image;
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
                dat.diamondbase.data_name = 'SuperResTest';
                dat.diamondbase.data_type = 'local';
                dat.images = obj.data;
                dat.meta = 'test';
            end
        end
        
      
       
      
    end
    
end

