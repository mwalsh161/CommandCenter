classdef Prologix < Modules.Driver
    
    properties
        
        ComHandle  % handle 
        
        comPortNum    % communication (COM) port number
        GPIBnum       % GPIB Channel
        GPIBbus       % GPIB bus

        Timeout = 2;      % TimeoutTime

        InputBufferSize = 2^16;
        OutputBufferSize = 2^16;

    end
    
    methods(Static)
        
        function obj = instance(varargin)     %In the format of 'COM#'
            mlock;
            
            persistent Object            
            
            if nargin ==3
                comPortNum = varargin{1};
                GPIBbus = varargin{2};
                GPIBnum = varargin{3};

                if isempty(Object) || ~isvalid(Object)
                    Object = Drivers.Prologix(comPortNum,GPIBbus,GPIBnum);
                end
                obj = Object;
            else
                
                if isempty(Object) || ~isvalid(Object)
                    Object = Drivers.Prologix();
                end
                obj = Object;
            end
            
        end
        
    end

    
    methods(Access=private)

        function [obj] = Prologix(varargin)


            if nargin==3
                obj.comPortNum = varargin{1};
                obj.GPIBbus = varargin{2};
                obj.GPIBnum = varargin{3};
            else
                prompt = {'Enter Serial port number (COM#):','Enter GPIB bus :','Enter GPIB number :'};
                dlg_title = 'SMIQ Communication Setting';
                num_lines = 1;
                defaultans = {'COM1','1','1'};
                answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
                
                obj.comPortNum = answer{1};
                obj.GPIBbus = str2num(answer{2});
                obj.GPIBnum = str2num(answer{3});
            end
            
            obj.ComHandle = serial(obj.comPortNum);
            set(obj.ComHandle,'Terminator','LF');
            set(obj.ComHandle,'Timeout',obj.Timeout);
            set(obj.ComHandle,'BaudRate',9600);
            set(obj.ComHandle,'Parity','none');
            set(obj.ComHandle,'DataBits',8);
            set(obj.ComHandle,'StopBits',1);
            
            set(obj.ComHandle,'InputBufferSize',obj.InputBufferSize);
            set(obj.ComHandle,'OutputBufferSize',obj.OutputBufferSize);
            
        end
    end
    
    methods
        
        function delete(obj)
            fclose(obj.ComHandle);
        end
        
        function writeOnly(obj,string)
            % check if the port is already open
            if (strcmp(obj.ComHandle.Status,'closed')),
                fopen(obj.ComHandle);
                CloseOnDone = 1;
            else
                CloseOnDone = 0;
            end
            
            obj.write_setting();
            obj.add_setting();
            
            fprintf(obj.ComHandle,string)
            
            if CloseOnDone
                fclose(obj.ComHandle);
            end
        end
        
        function [output] = writeRead(obj,string)
            if (strcmp(obj.ComHandle.Status,'closed')),
                fopen(obj.ComHandle);
                CloseOnDone = 1;
            else
                CloseOnDone = 0;
            end

            obj.read_setting();
            obj.add_setting();
            
            fprintf(obj.ComHandle,string)
            
            output = fscanf(obj.ComHandle);
            
            if CloseOnDone
                fclose(obj.ComHandle);
            end
        end

        function read_setting(obj)
            fprintf(obj.ComHandle,'++auto 1');
        end
        
        function write_setting(obj)
            fprintf(obj.ComHandle,'++auto 0');
        end

        function add_setting(obj)
            msg = sprintf('++addr 1');
            fprintf(obj.ComHandle,msg);
        end            
        
    end
end