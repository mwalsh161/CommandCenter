function varargout = inspector(varargin)
% INSPECTOR MATLAB code for inspector.fig
%      INSPECTOR, by itself, creates a new INSPECTOR or raises the existing
%      singleton*.
%
%      H = INSPECTOR returns the handle to a new INSPECTOR or the handle to
%      the existing singleton*.
%
%      INSPECTOR('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INSPECTOR.M with the given input arguments.
%
%      INSPECTOR('Property','Value',...) creates a new INSPECTOR or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before inspector_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to inspector_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help inspector

% Last Modified by GUIDE v2.5 05-Jan-2016 17:55:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @inspector_OpeningFcn, ...
                   'gui_OutputFcn',  @inspector_OutputFcn, ...
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


% --- Executes just before inspector is made visible.
function inspector_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to inspector (see VARARGIN)

% Choose default command line output for inspector
handles.output = hObject;
handles.node = varargin{1};  % One input argument, the node

handles.type.String = handles.node.type;
handles.units.String = handles.node.allowedUnits;
handles.units.Value = find(ismember(handles.node.allowedUnits,handles.node.units));
switch handles.node.type
    case 'transition'
        handles.data.String = 'Channel:';
        handles.data_field.Enable = 'off';
        handles.data_field.String = handles.node.data.label;
    case 'start'
        handles.data.String = 'Loop Variable:';
        handles.data_field.String = handles.node.data;
        handles.data_field.Enable = 'on';
    case 'end'
        handles.data.String = 'Number of Loops:';
        handles.data_field.String = num2str(handles.node.data);
        handles.data_field.Enable = 'on';
    case 'null'
        handles.data.String = 'Not Used!';
        handles.data_field.Enable = 'off';
end
if strcmp(handles.node.previous.type,'transition')
    handles.previous.String = sprintf('%s (%s)',handles.node.previous.type,handles.node.previous.data.label);
else
    handles.previous.String = handles.node.previous.type;
end
handles.previous_oldCallbacks = {};
seq = handles.node;
while isa(seq,'node')
    seq = seq.previous;
end
handles.sequence = seq;
updateDelta(handles)

addlistener(handles.sequence.editorH,'ObjectBeingDestroyed',@(~,~)delete(hObject));

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes inspector wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = inspector_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function delta_Callback(hObject, eventdata, handles)
% hObject    handle to delta (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of delta as text
%        str2double(get(hObject,'String')) returns contents of delta as a double
in = get(hObject,'String');
in_num = str2double(in);
if isnan(in_num)
    % Then must be a function
    parts = strsplit(in,'=');
    assert(numel(parts)==2,'Function declaration needs left and right side of equal sign!')
    vars = strsplit(parts{1}(3:end-1),',');
    dependent = sym.empty(0);
    eq = parts{2};
    for i = 1:numel(vars)
        dependent(end+1) = sym(vars{i});
        eq = strrep(eq,vars{i},sprintf('dependent(%i)',i));
    end
    handles.node.dependent = vars;
    val(dependent) = sym(sprintf('val(%s)',strjoin(vars,',')));
    val(dependent) = eval(eq);
else
    val = in_num;
    handles.node.dependent = [];
end
if ~isequal(handles.node.delta,val);  % AbortSet
    handles.node.delta = val;
    seq = handles.node;
    while ~isa(seq,'sequence')
        % Walk through tree till beginning
        seq = seq.previous;
    end
    seq.draw;
    updateDelta(handles)
end

function updateDelta(handles)
% Update text and GUI
contents = get(handles.units,'String');
units = contents{get(handles.units,'Value')};
handles.node.units = units;
if isnumeric(handles.node.delta)
    handles.delta.String = num2str(handles.node.delta);
else
    handles.delta.String = sprintf('f(%s)=%s',strjoin(handles.node.dependent,','),char(handles.node.delta));
end

% --- Executes during object creation, after setting all properties.
function delta_CreateFcn(hObject, eventdata, handles)
% hObject    handle to delta (see GCBO)
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
handles.node.units = contents{get(hObject,'Value')};
updateDelta(handles)

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



function data_field_Callback(hObject, eventdata, handles)
% hObject    handle to data_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of data_field as text
%        str2double(get(hObject,'String')) returns contents of data_field as a double
val = get(hObject,'String');
switch handles.node.type
    case 'start'
        handles.node.data = val;
    case 'end'
        val = str2double(val);
        if isnan(val)
            errordlg('Must be a number!')
            set(hObject,'String',num2str(handles.node.data))
        else
            handles.node.data = val;
        end
end
handles.sequence.draw;

% --- Executes during object creation, after setting all properties.
function data_field_CreateFcn(hObject, eventdata, handles)
% hObject    handle to data_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function previous_Callback(hObject, eventdata, handles)
% hObject    handle to previous (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of previous as text
%        str2double(get(hObject,'String')) returns contents of previous as a double


% --- Executes during object creation, after setting all properties.
function previous_CreateFcn(hObject, eventdata, handles)
% hObject    handle to previous (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over previous.
function previous_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to previous (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.previous_oldCallbacks)
    ax = findall(handles.sequence.editorH,'type','axes');
    options = findall(ax,'type','line');
    options(cellfun(@isempty,{options.Tag})) = [];
    ax = findall(handles.sequence.editorH,'type','axes');
    handles.previous_oldCallbacks = get(options,'ButtonDownFcn');
    set(options,'ButtonDownFcn',@(hObj,eventdata)inspector('selectPrevious',hObj.UserData,eventdata,guidata(hObject)))
    set(hObject,'BackgroundColor',[0.6 0.6 1])
    title(ax,'Select new node')
    guidata(hObject,handles)
end

% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if ~isempty(handles.previous_oldCallbacks)
    ax = findall(handles.sequence.editorH,'type','axes');
    options = findall(ax,'type','line');
    options(cellfun(@isempty,{options.Tag})) = [];
    set(options,{'ButtonDownFcn'},handles.previous_oldCallbacks)
    handles.previous_oldCallbacks = {};
    title(ax,'')
    set(handles.previous,'BackgroundColor','w')
    guidata(hObject,handles)
end

function selectPrevious(hObject,eventdata,handles)
% Note hObject is from different figure, but handles are still this
% figures.
handles.node.previous = hObject;
if strcmp(hObject.type,'transition')
    handles.previous.String = sprintf('%s (%s)',hObject.type,hObject.data.label);
else
    handles.previous.String = hObject.type;
end
ax = findall(handles.sequence.editorH,'type','axes');
title(ax,'')
set(handles.previous,'BackgroundColor','w')
handles.previous_oldCallbacks = {};
handles.sequence.draw;  % This resets callbacks
guidata(handles.figure1,handles)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

figure1_WindowButtonDownFcn(handles.figure1,[],guidata(handles.figure1))
delete(hObject);
