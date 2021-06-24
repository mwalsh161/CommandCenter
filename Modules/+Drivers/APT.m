classdef APT < handle
    
    %A simple class to super-class the APT devices which will also work for
    %the APT server (thus handle, and not a module)
    
    %If a control figure is closed, a new one will be spawned by
    %reinitializing
    
    %Note, this is not singleton, but it's children should be!
    
    properties(SetAccess=private)
        %The ActiveX Program ID.  This can be obtained from actxcontrollist
        progID
        %The window to hide the control in
        figureHandle
        %Serial number to identify the device.  Get from APT User
        serialNum
    end
    properties
        %The handle to the ActiveX control 
        controlHandle
    end
    properties(Constant,GetAccess=protected)
        % Properties for bit positions in getStatus
        MOVING_CLOCKWISE = 5;
        MOVING_COUNTERCLOCKWISE = 6;
        MOTOR_CONNECTED = 9;
%         HOMING = 10;
%         HOMED = 11;
        HOMED = 10;
    end
    methods
        %Method to get the current status bits.
        function status = getStatus(obj,bits)
            [~,status] = obj.LibraryFunction('LLGetStatusBits',0,0);
            
            if(nargin>1)
                status = bitget(abs(status),bits,'uint32');
            else
                status = bitget(abs(status),1:32,'uint32');
            end
        end
        
        %Prevent accidental closing
        function closeRequest(obj,varargin)
            if ~isempty(obj.figureHandle)
                obj.figureHandle.Visible = 'off';
            end
            
            if isempty(obj.progID)
                delete(obj.figureHandle)
            end
        end
        function show(obj,varargin)
            if ~isempty(obj.figureHandle)
                obj.figureHandle.Visible = 'on';
            end
            
            if isempty(obj.progID)
                delete(obj.figureHandle)
            end
        end
        %Destructor
        function delete(obj)
            %Stop control
            try %#ok<TRYNC>
                obj.LibraryFunction('StopCtrl');
                
                %Delete the ActiveX control
                delete(obj.controlHandle);
                %This signifies to close request that we're done
                obj.progID = [];
            end
            %Close the hidden window
            if isvalid(obj.figureHandle)
                close(obj.figureHandle);
            end
        end
    end
    methods
        %Method to issue library function to private controlHandle
        function varargout = LibraryFunction(obj,FunctionName,varargin)
            % determine how many outputs there should be for the function
            FunctionProto = obj.controlHandle.methods('-full');
            % find the matching name
            A = strfind(FunctionProto,FunctionName);
            fIndex = 0;
            for k=1:length(A)
                if ~isempty(A{k})
                    fIndex = k;
                    break
                end
            end
            assert(fIndex>0,sprintf('%s not found with given call signature.',FunctionName))
            % use regexp to get the number of args, given as [a, b, c, d]
            argText = regexp(FunctionProto{fIndex},'\[(.*)\]','match');
            if isempty(argText) % no [] proto implies 1 return
                nargs = 1;
            else
                nargs = length(regexp(argText{1}(2:end-1),'\w+'));
            end
            [varargout{1:nargs}] = eval(sprintf('obj.controlHandle.%s(varargin{:})',FunctionName));
            err = varargout{1};
            if err
                error('APT Server Error: %i. Serial Number %i.',err,obj.serialNum)
            end
        end
        
        % Wrapper to registerevent with private controlHandle
        function registerAPTevent(obj,varargin)
            obj.controlHandle.registerevent(varargin{:});
        end
        
        %Method to setup the control window and start the control
        function initialize(obj, progID, serialNum, figureHandle)
            % See if we can't find this component open already
            h = findall(0,'Tag',[progID,num2str(serialNum)]);
            if all(isgraphics(h)) && all(isvalid(h))
                close(h,'force');
            end

            if nargin < 4
                figureHandle = figure('HandleVisibility', 'Off', 'IntegerHandle', 'off', 'MenuBar', 'None', 'Position', [100 100 500 350]);
            end
            
            % give the figure a Tag associated with the SN so we can find it later!
            set(figureHandle,   'Visible', 'on', ...
                                'Tag', [progID, num2str(serialNum)],...
                                'CloseRequestFcn', @obj.closeRequest);

            % Initiate the activeX control
            obj.controlHandle = actxcontrol(progID,[0 0 500 350], figureHandle);
            if ~ischar(serialNum) % Things without official serial numbers are strings
                obj.controlHandle.HWSerialNum = serialNum;
            end
            
            obj.progID = progID;
            obj.figureHandle = figureHandle;
            obj.serialNum = serialNum;
            
            %Disable EventDlg if possible
            if ismethod(obj.controlHandle,'EnableEventDlg')
                obj.LibraryFunction('EnableEventDlg',false);
            end
            %Start the server
            obj.LibraryFunction('StartCtrl');
            
            %Do any special initialization
            obj.subInit()
        end

    end
    
    methods (Access = protected)
        function subInit(obj) %#ok<MANU>
            % Overload if necessary
        end
    end
    
end

