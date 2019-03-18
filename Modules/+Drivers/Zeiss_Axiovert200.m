classdef (Sealed) Zeiss_Axiovert200 < Modules.Driver
 % Driver for Axiovert200M microscope. Com port based communication that is handled through MicroManager
 
    methods(Access=private)
        function obj = Zeiss_Axiovert200()
            % Initialize Java Core
            addpath C:\Micro-Manager-1.4.22
            import mmcorej.*
            core=CMMCore;
            core.loadSystemConfiguration('C:\Micro-Manager-1.4.22\Zeiss_Axiovert200M_NoObjective_NoMCU28.cfg');
            obj.core = core;
            
            obj.FocusDevice = obj.core.getFocusDevice();
            obj.ZhomePos = obj.core.getPosition(obj.FocusDevice);
            obj.Zpos = obj.ZhomePos;
            obj.ExitPortState = str2double(obj.core.getProperty('ZeissSidePortTurret', 'State'));  % State 0 -> Widefield (camera port); State 1 is Confocal (left port 100%)
            obj.ReflectorState = str2double(obj.core.getProperty('ZeissReflectorTurret', 'State')); % State 0 -> Widefield (532 Dichro etc); State 1 -> Confocal (i.e. no reflector cube) 
            obj.HaloLampState = str2double(obj.core.getProperty('ZeissHalogenLamp','State')); % State 0 ->off ; State 1 -> on
            
            obj.HaloLampIntensity = str2double(obj.core.getProperty('ZeissHalogenLamp','Intensity'));
            
                        
            
            obj.loadPrefs;

        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Drivers.Zeiss_Axiovert200();
            end
            obj = Object;
        end
    end
    
    

    properties (SetObservable,AbortSet)
        Working = false     % In the middle of changing voltage (closely related to VoltageChange event)
        FocusDevice
        Zpos            % Z position in micrometers (no calbiration necessary, accurate down to ~50nm?)
        ZhomePos
        ExitPortState
        ReflectorState
        HaloLampState
        HaloLampIntensity
    end
    properties(Hidden,SetAccess=private) 
        core
    end

    properties(SetAccess=immutable)
        ZpositionLim      % Zposition limits of device, SK: not implemented but might need it.
    end
%     
%     events
%         % Triggered 0.1 second after setting to allow device to update itself
% %         VoltageChange
%         ZPosChange
%     end
%     
    
    methods
%         
%         function val = getHaloLampState(obj)
%             val = obj.core.getProperty('ZeissHalogenLamp', 'State');
%         end
        
        function set.HaloLampState(obj,val) % sets the focus position to val in micrometers
            obj.core.setProperty('ZeissHalogenLamp', 'State',num2str(val));
            obj.core.waitForSystem();
            obj.HaloLampState = str2double(obj.core.getProperty('ZeissHalogenLamp', 'State'));            
        end
        
%         function val = getHaloLampIntensity(obj)
%             val = obj.core.getProperty('ZeissHalogenLamp', 'Intensity');
%         end
        
        function set.HaloLampIntensity(obj,val) % sets the focus position to val in micrometers
            obj.core.setProperty('ZeissHalogenLamp', 'Intensity',num2str(val));
            obj.core.waitForSystem();
            obj.HaloLampIntensity = str2double(obj.core.getProperty('ZeissHalogenLamp', 'State'));
        end
        
%         function val = getExitPortState(obj)
%             val = obj.core.getProperty('ZeissSidePortTurret', 'State');
%         end
        
        function set.ExitPortState(obj,val) % sets the focus position to val in micrometers
            obj.core.setProperty('ZeissSidePortTurret', 'State',num2str(val));
            obj.core.waitForSystem();
            obj.ExitPortState = str2double(obj.core.getProperty('ZeissSidePortTurret', 'State'));
        end
        
%         function val = get.ReflectorState(obj)
%             val = 
%         end
        
        function set.ReflectorState(obj,val) % sets the focus position to val in micrometers
            obj.core.setProperty('ZeissReflectorTurret', 'State',num2str(val));
            obj.core.waitForSystem();
            obj.ReflectorState = str2double(obj.core.getProperty('ZeissReflectorTurret', 'State'));
        end
        
        function val = getZpos(obj)
            val = obj.core.getPosition(obj.FocusDevice);
        end
        
        function setZpos(obj,val) % sets the focus position to val in micrometers
            obj.core.setPosition(obj.FocusDevice,val); 
            obj.core.waitForSystem();
            obj.Zpos = obj.core.getPosition(obj.FocusDevice);
        end
        
        function step(obj,dz) % step in Z by dz (in micrometers)
            Zcur = obj.getZpos();
            newZpos = Zcur + dz;
            obj.setZpos(newZpos);
        end
        
        function delete(obj)
            delete(obj.core)
        end
    end
end
      
