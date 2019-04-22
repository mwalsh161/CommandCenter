function [comObject,comObjectInfo] = Connect_Driver(varargin)
%% Connect_Driver
% Handles connecting to your computer to your driver(s).
%
%% Syntax
%  Connect_Driver();
%  Connect_Driver(comProperties);
%  Connect_Driver(comProperties,deviceID);
%% Description
%  Helper function that handles connecting to your driver. Uses the helper
%  function Connect_Device. The handle to your device will be returned and
%  it will be open and ready to use.
%
%% Input arguments (defaults exist):

% comProperties - desired settings of comObject

% deviceID - id of device. Can be anything, for example call query(comObject,'*IDN?') to get.
%% Output arguments
%	[comObject,comProperties] - neccessary information to establish future
%	connections. If connection cannot be established returns [].

% comObject - handle to device

% comProperties - is a struct with fields aligned with properties of the
% comObject

%Note: Cancel returns [] for comObject, but returns last entered comProperties
%% handle inputs
narginchk(0,2); %should have no more than two inputs
numInputs = nargin;

if numInputs == 2
    if  ~isempty(varargin{2})
        assert(ischar(varargin{2}),'device id must be a string')
    else
        varargin(2) = [];
        numInputs = 1;
    end
end

if numInputs >= 1
    if ~isempty(varargin{1})
        assert(isstruct(varargin{1}) ,'comProperties must be a structure.')
    else
        varargin(1) = [];
        numInputs = 0;
    end
end

if numInputs ==2
    deviceID = varargin{2};
else
    deviceID = [];
end

%% initialize outputs
comObject = [];

%% if there are no inputs

if numInputs == 0
    %first time connecting should run the helperfunction
    %Connect_Device to establish your connection
    [comObject,comProperties] = Connect_Device;
    
end

if numInputs > 0
    %this is used for connecting every time after the first
    %time
    [comObject,comProperties] = Connect_Device(varargin{1});
end

%% try opening your device

%first see if there is already an open hardware line of the same name
comObject = openHandle(comObject);

%now try opening the line
ME = [];
try
    if strcmpi(comObject.Status,'closed') %if closed then open
        fopen(comObject); %open connection to your device
    end
catch ME
    %ask user if they want to enter in a new comm address
    [comObject,comProperties] = messageUser(comObject,comProperties,deviceID);
    if ~isempty(comObject)
        comObject = openHandle(comObject);
        if strcmpi(comObject.Status,'closed') %if closed then open
            fopen(comObject); %open connection to your device
        end
        ME = []; %clear errors
    end
    
end

%% rethrow errors

if ~isempty(ME)
    message = sprintf('Failed to open device. Error message: %s',ME.identifier);
    f = msgbox(message);
    rethrow(ME)
end
end

function [comObject,comProperties] = messageUser(comObject,comProperties,deviceID)
%this is only called if you failed to connect to your device(ex: change GPIB
%address). This allows you to establish a new
%connection.

line1 = 'Problem connecting to your device. ';

if ~isempty(deviceID)
    line2 = sprintf('Device name: %s. ',deviceID);
else
    line2 = [];
end

line3 = sprintf('Connection was of type %s. ',class(comObject));

for index = 1:numel(comObject.UserData)
    if numel(comObject.UserData) > 1 %handles gpib, prologix and TCP
        if index == 1
            line4 = sprintf('No device found on input address %s',string(comObject.UserData{index}));
        elseif index == numel(comObject.UserData)
            line4 = [line4,sprintf(', and %s. ',string(comObject.UserData{index}))];
        else
            line4 = [line4,sprintf(', %s',string(comObject.UserData{index}))];
        end
    end
    
    if  numel(comObject.UserData) == 1% handles serial
        line4 = sprintf('No device found on input address %s. ',string(comObject.UserData{index}));
    end
end

line5 = 'Do you wish to re-enter your communication address?';
question = [line1,line2,line3,line4,line5];
title = 'Communication Failure';
defbtn = [{'yes'},{'no'}];
answer = questdlg(question, title,defbtn);
comObject = [];
if strcmpi(answer,'yes')
    [comObject,comProperties] = Connect_Device;
end
end

function comObject = openHandle(comObject)

handles = instrfindall;
for index =  1 : numel(handles)
    name = handles(index).name;
    if strcmpi(name,comObject.name)
        if strcmpi(handles(index).status,'open')
            comObject =  handles(index); %if a hardware line of the same name exists that is open take that handle
        end
    end
end
end