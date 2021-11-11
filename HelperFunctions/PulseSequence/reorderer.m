function varargout = reorderer(varargin)
% REORDERER MATLAB code for reorderer.fig
%      REORDERER, by itself, creates a new REORDERER or raises the existing
%      singleton*.
%
%      H = REORDERER returns the handle to a new REORDERER or the handle to
%      the existing singleton*.
%
%      REORDERER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in REORDERER.M with the given input arguments.
%
%      REORDERER('Property','Value',...) creates a new REORDERER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before reorderer_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to reorderer_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help reorderer

% Last Modified by GUIDE v2.5 05-Jan-2016 16:58:41

% Begin initialization code - DO NOT EDIT
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @reorderer_OpeningFcn, ...
                   'gui_OutputFcn',  @reorderer_OutputFcn, ...
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


% --- Executes just before reorderer is made visible.
function reorderer_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to reorderer (see VARARGIN)

% Choose default command line output for reorderer
handles.output = hObject;
handles.listbox.String = varargin{1};
handles.original = varargin{1};

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes reorderer wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = reorderer_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
s = numel(handles.listbox.String);
indexOrder = ones(1,s);
for i = 1:s
    indexOrder(i) = find(ismember(handles.original,handles.listbox.String{i}));
end
varargout{1} = handles.listbox.String;
varargout{2} = indexOrder;
delete(handles.figure1)

% --- Executes on selection change in listbox.
function listbox_Callback(hObject, eventdata, handles)
% hObject    handle to listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox


% --- Executes during object creation, after setting all properties.
function listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in up.
function up_Callback(hObject, eventdata, handles)
% hObject    handle to up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selected = get(handles.listbox,'Value');
options = get(handles.listbox,'String');
if selected > 1
    temp = options{selected-1};
    options{selected-1} = options{selected};
    options{selected} = temp;
    set(handles.listbox,'String',options)
    set(handles.listbox,'Value',selected-1)
end

% --- Executes on button press in down.
function down_Callback(hObject, eventdata, handles)
% hObject    handle to down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selected = get(handles.listbox,'Value');
options = get(handles.listbox,'String');
if selected+1 <= numel(options)
    temp = options{selected+1};
    options{selected+1} = options{selected};
    options{selected} = temp;
    set(handles.listbox,'String',options)
    set(handles.listbox,'Value',selected+1)
end


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isequal(get(hObject, 'waitstatus'), 'waiting')
    % The GUI is still in UIWAIT, us UIRESUME
    uiresume(hObject);
else
    % The GUI is no longer waiting, just close it
    delete(hObject);
end


% --- Executes on button press in ok.
function ok_Callback(hObject, eventdata, handles)
% hObject    handle to ok (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(handles.figure1)

% --- Executes on button press in cancel.
function cancel_Callback(hObject, eventdata, handles)
% hObject    handle to cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.listbox.String = handles.original;
close(handles.figure1)
