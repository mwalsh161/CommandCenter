classdef CMOS_Chip_Control < Modules.Source
    %class designed to control the CMOS chip
    
    properties
        setLimit = {0,0,0,0,0,0,0}
        HAMEG_handle
        HMP4040_handle
        prefs = {'VDD_VCO','VDD_Driver','DriverCore','DriverBoundary'...
            'VDDCP','VDDPLL'}
    end
    
    properties(SetObservable)
        %% HMP4040
        
        VDD_VCO = 1;  %channel 1
        VDD_Driver = 1;%channel 2
        DriverCore = 0.8; %channel 3
        DriverBoundary = 0.8;%channel 4
        
        %% HAMEG
        
        VDDCP = 1.4;%channel 1
        VDDPLL = 1;%channel 2
        
    end
    
    properties (Constant)
        %% VCO properties
        
        VDD_VCO_min = 0; %V
        VDD_VCO_max = 1.1;%V
        VDD_VCO_CLim = 0.02; %A
        %% VDD_Driver properties
        
        VDD_Driver_min = 0;%V
        VDD_Driver_max = 1;%V
        VDD_Driver_CLim = 0.050; %A
        %% DriverCore
        
        DriverCore_min = 0; %V
        DriverCore_max = 1.05; %V
        DriverCore_CLim = 0.005; %A
        %% DriverBoundary
        
        DriverBoundary_min = 0 %V
        DriverBoundary_max = 1.05%V
        DriverBoundary_CLim = 0.005; %A
        
        %% VDDCP
        
        VDDCP_min = 0; %V
        VDDCP_max = 1.6; %V
        VDDCP_CLim = 10e-3; %A
        
        %% VDDPLL
        
        VDDPLL_min = 0; %V
        VDDPLL_max = 1.1%V
        VDDPLL_CLim = 0.01; %A
       
    end
    
    properties(SetAccess=private, SetObservable, AbortSet)
        source_on=false;
    end
    
    properties(SetAccess=private)
        path_button
    end
    
    methods(Access = private)
        function obj = CMOS_Chip_Control()
            obj.HAMEG_handle = Sources.PowerSupplies.HAMEG_Source.instance;
            obj.HMP4040_handle = Sources.PowerSupplies.HMP4040_Source.instance;
            
            %%
            obj.loadPrefs;
            
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.CMOS_Chip_Control();
            end
            obj = Object;
        end
        
    end
    
    methods
        %% set methods
        function set.VDD_VCO(obj,val)
            obj.checkVal('VDD_VCO',val)
            obj.HMP4040_handle.Channel = '1';
            obj.HMP4040_handle.Source_Mode = 'Voltage';
            if obj.setLimit{1} == 0
                obj.HMP4040_handle.Current_Limit = obj.VDD_VCO_CLim;
                obj.setLimit{1} = 1;
            end
            obj.HMP4040_handle.Voltage = val;
            obj.VDD_VCO = val;
        end
        
        function set.VDD_Driver(obj,val)
            obj.checkVal('VDD_Driver',val)
            obj.HMP4040_handle.Channel = '2';
            obj.HMP4040_handle.Source_Mode = 'Voltage';
            if obj.setLimit{2} == 0
                obj.HMP4040_handle.Current_Limit = obj.VDD_Driver_CLim;
                obj.setLimit{2} = 1;
            end
            obj.HMP4040_handle.Voltage = val;
            obj.VDD_Driver = val;
        end
        
        function set.DriverCore(obj,val)
            obj.checkVal('DriverCore',val)
            obj.HMP4040_handle.Channel = '3';
            obj.HMP4040_handle.Source_Mode = 'Voltage';
            if obj.setLimit{3} == 0
                obj.HMP4040_handle.Current_Limit = obj.DriverCore_CLim;
                obj.setLimit{3} = 1;
            end
            obj.HMP4040_handle.Voltage = val;
            obj.DriverCore =val;
        end
        
        function set.DriverBoundary(obj,val)
            obj.checkVal('DriverBoundary',val)
            obj.HMP4040_handle.Channel = '4';
            obj.HMP4040_handle.Source_Mode = 'Voltage';
            if obj.setLimit{4} == 0
                obj.HMP4040_handle.Current_Limit = obj.DriverBoundary_CLim;
                obj.setLimit{4} = 1;
            end
            obj.HMP4040_handle.Voltage = val;
            obj.DriverBoundary = val;
        end
        
        function set.VDDCP(obj,val)
            obj.checkVal('VDDCP',val)
            obj.HAMEG_handle.Channel = '1';
            obj.HAMEG_handle.Source_Mode = 'Voltage';
            if obj.setLimit{5} == 0
                obj.HAMEG_handle.Current_Limit = obj.VDDCP_CLim;
                obj.setLimit{5} = 1;
            end
            obj.HAMEG_handle.Voltage = val;
            obj.VDDCP = val;
        end
        
        function set.VDDPLL(obj,val)
            obj.checkVal('VDDPLL',val)
            obj.HAMEG_handle.Channel = '2';
            obj.HAMEG_handle.Source_Mode = 'Voltage';
            if obj.setLimit{6} == 0
                obj.HAMEG_handle.Current_Limit = obj.VDDPLL_CLim;
                obj.setLimit{6} = 1;
            end
            obj.HAMEG_handle.Voltage = val;
            obj.VDDPLL = val;
        end
        %%
        
        
        function delete(obj)
            obj.HAMEG_handle.delete;
            obj.HMP4040_handle.delete;
        end
        
        function on(obj)           
            obj.HMP4040_handle.on;
            obj.HAMEG_handle.on;
            obj.source_on=1;
        end
        
        function off(obj)
            obj.HAMEG_handle.off;
            obj.HMP4040_handle.off;
            obj.source_on=0;
        end
        
        function checkVal(obj,propName,val)
            assert(isnumeric(val),['Values for ',propName,' must be numeric'])
            assert(val >= obj.([propName,'_min']),[propName,' values be greater than ',num2str(obj.([propName,'_min'])),' V.'])
            assert(val <= obj.([propName,'_max']),[propName,' values be less than ',num2str(obj.([propName,'_max'])),' V.'])
        end
        
    end
end
