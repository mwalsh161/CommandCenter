function [comObject,comObjectInfo,deviceID] = Connect_Driver(varargin)
%% Connect_Driver
% Handles connecting to your computer to your driver(s).
%
%% Syntax
%  Connect_Driver();
%  Connect_Driver( [{comType},{comAddress},{comProperties}]);
%  Connect_Driver( [{comType},{comAddress},{comProperties}],deviceID);
%% Description
%  Helper function that handles connecting to your driver. Uses the helper
%  function Connect_Device. The handle to your device will be returned and
%  it will be open and ready to use.
%
%% Input arguments (defaults exist):
% comType -  %type of connection: Serial/GPIB/Prologix

% comAddress - %address needed to start connection

% comProperties - desired settings of comObject

% deviceID - id of device. Call query(comObject,'*IDN?') to get.
%% Output arguments
%	[comObject,comObjectInfo,deviceID] - neccessary information to establish future
%	connections. If connection cannot be established returns [].

% comObjectInfo - is a struct with fields containing comType,comAddress,and comProperties

%Note: Cancel returns []
%% handle inputs
nargincheck(1,2); %should have at least one input and and no more than three inputs
numInputs = nargin;

if numInputs == 2
    if  ~isempty(varargin{2})&& ~isempty(varargin{1})
        assert(ischar(varargin{2}),'device id must be a string')
    else
        varargin(2) = [];
        numInputs = 1;
    end
end

if numInputs == 1
    if ~isempty(varargin{1})
        assert(iscell(varargin{2}),'Second input must be a cell array.')
        assert(numel(varargin{2}) == 3 ,'Cell array must have three elements.')
        assert(ischar(varargin{2}{1,1}) ,'comType must be a string.')
        assert(iscell(varargin{2}{1,2}) ,'comAddress must be a cell.')
        assert(isstruct(varargin{2}{1,3}) ,'comProperties must be a structure.')
    else
        varargin(1) = [];
        numInputs = 0;
    end
end


%% initialize outputs

comObject = [];
comObjectInfo = struct();
deviceID = [];
%% if there are no inputs

if numInputs == 0
    %first time connecting should run the helperfunction
    %Connect_Device to establish your connection
    [comObject,comObjectInfo.comType,comObjectInfo.comAddress,comObjectInfo.comProperties] = Connect_Device;
    
end

if numInputs > 0
    %this is used for connecting every time after the first
    %time
    try
        comObjectInfo.comType = varargin{1,1};
        comObjectInfo.comAddress = varargin{1,2};
        comObjectInfo.comProperties = varargin{1,3};
        
        [comObject,comObjectInfo.comType,comObjectInfo.comAddress,comObjectInfo.comProperties] = ...
            Connect_Device(comObjectInfo.comType,comObjectInfo.comAddress,comObjectInfo.comProperties);
    catch
        
        %this is only called if you failed to connect to your device(ex: change GPIB
        %address). This allows you to establish a new
        %connection.
        
        if numInputs == 2
            deviceID = varargin{2};
        end
        
        line1 = 'Problem connecting to your device. ';
        
        if ~isempty(deviceID)
            line2 = sprintf('Device name: %s. ',deviceID);
        else
            line2 = [];
        end
        
        line3 = sprintf('Connection was of type %s. ',comObjectInfo.comType);
        
        for index = 1:numel(comObjectInfo.comAddress)
            if index == 1
                line4 = sprintf('Previous address was %s',string(comObjectInfo.comAddress{index}));
            elseif index == numel(comObjectInfo.comAddress)
                line4 = [line4,sprintf(', and %s. ',string(comObjectInfo.comAddress{index}))];
            else
                line4 = [line4,sprintf(', %s',string(comObjectInfo.comAddress{index}))];
            end
        end
        
        line5 = 'Do you wish to re-enter your communication address?';
        question = [line1,line2,line3,line4,line5];
        title = 'Communication Failure';
        defbtn = [{'yes'},{'no'}];
        answer = questdlg(question, title,defbtn);
        if strcmpi(answer,'yes')
            [comObject,comObjectInfo.comType,comObjectInfo.comAddress,comObjectInfo.comProperties] ...
                = Connect_Device;
        end
    end
end
%% try opening your device

try
    
    fopen(comObject); %open connection to your device
    deviceID = query(comObject); %get device id
catch ME
    message = sprintf('Failed to open device. Error message: %s',ME.identifier);
    f = msgbox(message);
    rethrow(ME)
end
end
