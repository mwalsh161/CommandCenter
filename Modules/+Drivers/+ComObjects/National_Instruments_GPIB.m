classdef National_Instruments_GPIB < Drivers.ComObjects.ComDevice & Modules.Driver
    
    % Matlab Object Class implementing control for National Instrument GPIB
    % to USB devices.
    %   
    % Communication can be established by first downloading and installing
    % the correct drivers.
    % Software is called NI MAX. CD can be found within CD book.
    
    % Adaptor_Type depends on vendor. Supports: agilent, ics, mcc, ni
    % 
    % GPIBboard_Number can be found by opening NI MAX software. Ex: GPIB0::18::INSTR
    % found under VISA Resource Name means that you have a
    % GPIBboard_Number=0 and your device has a GPIBnum address of 18.
    % 
    % GPIBnum can also be determined from your devices. Check its setting to determine the address.
    
    % Primary purpose of this is to control the talk to various devices.
    % When a device's drivers are instantiation, they should call the
    % helper function Connect_Device. Connect_Device will ask the user to
    % select which communication driver he would like. 
   
    properties
       Timeout = 2;      % TimeoutTime
       InputBufferSize = 2^16;
       OutputBufferSize = 2^16;  
    end
   
    properties(SetAccess=private)
        ComHandle  % handle
        Adaptor_Type    %which adaptor type as defined by matlab for instance "ni"
        GPIBboard_Number    % GPIB Board Number
        GPIBnum       % GPIB Number
    end
    
    properties(Constant)
        InputArg={'Adaptor_Type','GPIBboard_Number','GPIBnum'}
    end
    
    methods(Static)
        function obj = instance(Adaptor,GPIBboard_Number,GPIBnum)
            Adaptor = lower(Adaptor);
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.ComObjects.National_Instruments_GPIB.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal({Adaptor,GPIBboard_Number,GPIBnum},Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj =Drivers.ComObjects.National_Instruments_GPIB(Adaptor,GPIBboard_Number,GPIBnum);
            obj.singleton_id = {Adaptor,GPIBboard_Number,GPIBnum};
            Objects(end+1) = obj;
        end
    end
    
    
    methods(Access=private)
        
        function [obj] = National_Instruments_GPIB(Adaptor,GPIBboard_Number,GPIBnum)
            
            obj.Adaptor_Type=Adaptor;
            obj.GPIBboard_Number=GPIBboard_Number;
            obj.GPIBnum=GPIBnum;
            
            obj.ComHandle =gpib(obj.Adaptor_Type, str2num(obj.GPIBboard_Number),str2num(obj.GPIBnum));
            
            obj.set_ComPort_properties;
            fclose(obj.ComHandle);
            try
                fopen(obj.ComHandle);
            catch
                instruments=instrfind;
                for index=1:length(instruments)
                    if strcmp(instruments(index).name,obj.ComHandle.name)
                        if  strcmp(instruments(index).status,'closed')
                            delete(instruments(index))
                        elseif  strcmp(instruments(index).status,'open')
                            obj.ComHandle=instruments(index);
                        end
                    end
                end
                
            end
        end
        
        function set_ComPort_properties(obj)
            %must set these properties before opening!
            set(obj.ComHandle,'Timeout',obj.Timeout);
            set(obj.ComHandle,'InputBufferSize',obj.InputBufferSize);
            set(obj.ComHandle,'OutputBufferSize',obj.OutputBufferSize);
        end
        
    end
    methods
        
        function delete(obj)
            fclose(obj.ComHandle);
            delete(obj.ComHandle);
        end
        
        function reset(obj)
            obj.Timeout = 2;      % TimeoutTime
            obj.InputBufferSize = 2^16;
            obj.OutputBufferSize = 2^16;
        end
        
        function writeOnly(obj,string)
            fclose(obj.ComHandle);
            obj.set_ComPort_properties;
            fopen(obj.ComHandle);
            fprintf(obj.ComHandle,string);
            fclose(obj.ComHandle); %close after writing.
        end
        
        function [output] = writeRead(obj,string)
            fclose(obj.ComHandle);
            obj.set_ComPort_properties
            fopen(obj.ComHandle);
            output = query(obj.ComHandle,string); 
            fclose(obj.ComHandle); %close after writing.
        end

    end
end