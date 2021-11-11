function varargout = newChannel(varargin)
% NEWCHANNEL MATLAB code for newChannel.fig
%      NEWCHANNEL, by itself, creates a new NEWCHANNEL or raises the existing
%      singleton*.
%
%      H = NEWCHANNEL returns the handle to a new NEWCHANNEL or the handle to
%      the existing singleton*.
%
%      NEWCHANNEL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in NEWCHANNEL.M with the given input arguments.
%
%      NEWCHANNEL('Property','Value',...) creates a new NEWCHANNEL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before newChannel_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to newChannel_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help newChannel

% Last Modified by GUIDE v2.5 09-Jul-2016 15:18:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @newChannel_OpeningFcn, ...
                   'gui_OutputFcn',  @newChannel_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before newChannel is made visible.
function newChannel_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to newChannel (see VARARGIN)

% Choose default command line output for newChannel
handles.output = [];
if numel(varargin)> 0
    handles.channel = varargin{1};
    handles.cancel.Enable = 'off';  % We update object immediately
    handles.figure1.Name = 'EditChannel';
else
    handles.channel = channel('PlaceHolder');
end
handles.units.String = handles.channel.allowedUnits;
handles.label.String = handles.channel.label;
handles.offset.String = num2str(handles.channel.offset);
ind = find(ismember(handles.units.String,handles.channel.units));
handles.units.Value = ind;
handles.hardware.String = num2str(handles.channel.hardware);
set(handles.color,'BackgroundColor',handles.channel.color)

index = 1;
try
    % FUTURE: get rid of hardcoded 'dev1'
    ni = Drivers.NIDAQ.dev.instance('dev1');
    opts = [{''} {ni.InLines().name}];
    index = find(strcmp(handles.channel.counter,opts));
    if isempty(index)
        opts = sprintf('Error: %s not found',handles.channel.counter);
    end
catch % Turn to text input
    opts = handles.channel.counter;
    handles.counter.Style = 'edit';
end

handles.counter.String = opts;
handles.counter.Value = index;
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes newChannel wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = newChannel_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
delete(handles.figure1)


function label_Callback(hObject, eventdata, handles)
% hObject    handle to label (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.channel.label = get(hObject,'String');


% --- Executes during object creation, after setting all properties.
function label_CreateFcn(hObject, eventdata, handles)
% hObject    handle to label (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function offset_Callback(hObject, eventdata, handles)
% hObject    handle to offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

val = str2double(get(hObject,'String'));
if isnan(val)
    errordlg('Must be a number!')
    set(hObject,'String',num2str(handles.channel.offset))
else
    handles.channel.offset = val;
end

% --- Executes during object creation, after setting all properties.
function offset_CreateFcn(hObject, eventdata, handles)
% hObject    handle to offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in units.
function units_Callback(hObject, eventdata, handles)
% hObject    handle to units (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
contents = get(hObject,'String');
handles.channel.units = contents{get(hObject,'Value')};
set(handles.offset,'String',num2str(get(hObject,'String')))

% --- Executes during object creation, after setting all properties.
function units_CreateFcn(hObject, eventdata, handles)
% hObject    handle to units (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function hardware_Callback(hObject, eventdata, handles)
% hObject    handle to hardware (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

val = str2double(get(hObject,'String'));
if isnan(val)
    errordlg('Must be a number!')
    set(hObject,'String',num2str(handles.channel.hardware))
else
    handles.channel.hardware = val;
end

% --- Executes during object creation, after setting all properties.
function hardware_CreateFcn(hObject, eventdata, handles)
% hObject    handle to hardware (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ok.
function ok_Callback(hObject, eventdata, handles)
% hObject    handle to ok (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.output = handles.channel;
guidata(hObject,handles)
close(handles.figure1)

% --- Executes on button press in cancel.
function cancel_Callback(hObject, eventdata, handles)
% hObject    handle to cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.output = [];
close(handles.figure1)

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structupushbutton3re with handles and user data (see GUIDATA)
if isequal(get(hObject, 'waitstatus'), 'waiting')
    % The GUI is still in UIWAIT, us UIRESUME
    uiresume(hObject);
else
    % The GUI is no longer waiting, just close it
    delete(hObject);
end


% --- Executes on button press in color.
function color_Callback(hObject, eventdata, handles)
% hObject    handle to color (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
c = uisetcolor;
set(hObject,'BackgroundColor',c)
handles.channel.color = c;


% --- Executes on button press in counter.
function counter_Callback(hObject, eventdata, handles)
% hObject    handle to counter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if strcmp(hObject.Style,'edit')
    handles.channel.counter = get(hObject,'string');
elseif strcmp(hObject.Style,'popup')
    selection = get(hObject,'Value');
    opts = get(hObject,'string');
    handles.channel.counter = opts{selection};
end

% --- Executes during object creation, after setting all properties.
function counter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to counter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over counter.
function counter_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to counter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% FUTURE: add updating here 