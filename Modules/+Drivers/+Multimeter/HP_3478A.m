classdef HP_3478A < Drivers.Multimeter.Multimeter & Modules.Driver
    
    properties 
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','') 
        comObject;     % USB-Serial/GPIB/Prologix
    end
 
    properties (Constant)
        Number_of_channels='1'
        dev_id = 'HP_3478A'
    end
    
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Multimeter.HP_3478A.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Multimeter.HP_3478A();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
  
    methods(Access=private)
        function [obj] = HP_3478A()
            obj.loadPrefs;
            display('setting comInfo for HP_3478A.')
%             if isempty(obj.comObjectInfo.comType)&& isempty(obj.comObjectInfo.comAddress)&& isempty(obj.comObjectInfo.comProperties)
%                 [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = Connect_Device;
%             else
%                 try
%                     [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = ...
%                         Connect_Device(obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties);
%                 catch
%                     [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
%                         = Connect_Device;
%                 end
%             end
            obj.comObject = prologix('com3',23);
            if strcmpi(obj.comObject.Status,'closed')
                fopen(obj.comObject);
            end
        end
    end
    
    methods(Access=private)
        
        function check_channel(obj,channel)
            assert(ischar(channel),'Channel input must be a string!')
            assert(strcmp(channel,'1'),'HP_3478A only supports channel inputs of ''1''!')
        end
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
    end
    
    methods
        
        function setVoltRange(obj)
          warning([obj.dev_id,' does not have a set_volt_range method.'])   
        end
        
        function setCurrentRange(obj)
           warning([obj.dev_id,' does not have a set_current_range method.'])   
        end
        
        %%
        
        function  [voltage] = measureVoltage(obj,channel)
            obj.check_channel(channel)
            string=sprintf('H1');
            s = obj.writeRead(string);
            voltage=str2num(s(1:end-1));
        end
        
        function  [current] = measureCurrent(obj,channel)
            obj.check_channel(channel)
            string=sprintf('H5');
            s = obj.writeRead(string);
            current=str2num(s(1:end-1));
        end
        %% 
        function on(obj)
          warning([obj.dev_id,' does not have an on method. Must be turned on manually.'])  
        end
        
        function off(obj)
           warning([obj.dev_id,' does not have an off method. Must be turned off manually.'])   
        end
        
        function delete(obj)
            string=sprintf('LOCAL 7');
            obj.writeOnly(string);
            fclose(obj.comObject);
            delete(obj.comObject);
        end
    end
end