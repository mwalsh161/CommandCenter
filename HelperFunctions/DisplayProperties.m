function varargout = DisplayProperties(varargin)
%DisplayProperties M-file for DisplayProperties.fig
%      DisplayProperties, by itself, creates a new DisplayProperties or raises the existing
%      singleton*.
%
%      H = DisplayProperties returns the handle to a new DisplayProperties or the handle to
%      the existing singleton*.
%
%      DisplayProperties('Property','Value',...) creates a new DisplayProperties using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to DisplayProperties_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      DisplayProperties('CALLBACK') and DisplayProperties('CALLBACK',hObject,...) call the
%      local function named CALLBACK in DisplayProperties.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help DisplayProperties

% Last Modified by GUIDE v2.5 31-Mar-2015 11:51:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @DisplayProperties_OpeningFcn, ...
                   'gui_OutputFcn',  @DisplayProperties_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
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


% --- Executes just before DisplayProperties is made visible.
function DisplayProperties_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for DisplayProperties
stagesLoaded = varargin{1};
stagesLoadedVerified = {};
stages = get(handles.modules,'string');
notFound = {};
for i = 1:numel(stagesLoaded)
    mask = ismember(stages,stagesLoaded{i});
    if sum(mask)
        stages(mask)=[];
        stagesLoadedVerified{end+1} = stagesLoaded{i};
    else
        notFound{end+1} = stagesLoaded{i};
    end
end
if ~isempty(notFound)
    notFound = strjoin(notFound,'\n');
    notFound = sprintf('Did not find the following stages (used previously) in the Stages folder:\n%s',notFound);
    warndlg(notFound)
end
set(handles.modules,'string',stages)
set(handles.UsedModules,'string',stagesLoadedVerified)
set(handles.status,'String','Make sure the stage modules being used are in the correct order!')
handles.success = false;
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes StageManagerEdit wait for user response (see UIRESUME)
uiwait(handles.figure1);



% --- Outputs from this function are returned to the command line.
function varargout = DisplayProperties_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = get(handles.UsedModules,'String');
varargout{2} = handles.success;
delete(handles.figure1)

% --- Executes on selection change in modules.
function modules_Callback(hObject, eventdata, handles)
% hObject    handle to modules (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns modules contents as cell array
%        contents{get(hObject,'Value')} returns selected item from modules


% --- Executes during object creation, after setting all properties.
function modules_CreateFcn(hObject, eventdata, handles)
% hObject    handle to modules (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
[path,~,~] = fileparts(mfilename('fullpath'));
[prefix,module_strs,packages] = Base.GetClasses(path,'..','+Stages');
module_strs = cellfun(@(n)[prefix n],module_strs,'UniformOutput',false);
set(hObject,'string',module_strs)

% --- Executes on selection change in UsedModules.
function UsedModules_Callback(hObject, eventdata, handles)
% hObject    handle to UsedModules (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns UsedModules contents as cell array
%        contents{get(hObject,'Value')} returns selected item from UsedModules


% --- Executes during object creation, after setting all properties.
function UsedModules_CreateFcn(hObject, eventdata, handles)
% hObject    handle to UsedModules (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in add.
function add_Callback(hObject, eventdata, handles)
% hObject    handle to add (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
values = get(handles.modules,'value');
found_modules = get(handles.modules,'String');
used_modules = get(handles.UsedModules,'String');
used_modules = [used_modules; found_modules(values)];
found_modules(values) = [];
set(handles.modules,'Value',[],'String',found_modules)
set(handles.UsedModules,'String',used_modules)

% --- Executes on button press in remove.
function remove_Callback(hObject, eventdata, handles)
% hObject    handle to remove (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = get(handles.UsedModules,'value');
used_modules = get(handles.UsedModules,'String');
if ~isempty(used_modules)
    found_modules = get(handles.modules,'String');
    found_modules = [found_modules; used_modules(val)];
    used_modules(val) = [];
    set(handles.UsedModules,'Value',max(val-1,1),'String',used_modules)
    set(handles.modules,'String',found_modules)
end

% --- Executes on button press in pushbutton3 (continue).
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'enable','off')
handles.success = true;
guidata(hObject,handles)
close(handles.figure1)

% --- Executes on button press in up.
function up_Callback(hObject, eventdata, handles)
% hObject    handle to up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = get(handles.UsedModules,'value');
used_modules = get(handles.UsedModules,'String');
if val > 1
    temp = used_modules{val};
    used_modules{val} = used_modules{val-1};
    used_modules{val-1} = temp;
    set(handles.UsedModules,'String',used_modules)
    set(handles.UsedModules,'Value',val-1)
end

% --- Executes on button press in down.
function down_Callback(hObject, eventdata, handles)
% hObject    handle to down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = get(handles.UsedModules,'value');
used_modules = get(handles.UsedModules,'String');
if val < numel(used_modules)
    temp = used_modules{val};
    used_modules{val} = used_modules{val+1};
    used_modules{val+1} = temp;
    set(handles.UsedModules,'String',used_modules)
    set(handles.UsedModules,'Value',val+1)
end

% --- Executes during object creation, after setting all properties.
function up_CreateFcn(hObject, eventdata, handles)
% hObject    handle to up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'string',char(8593))

% --- Executes during object creation, after setting all properties.
function down_CreateFcn(hObject, eventdata, handles)
% hObject    handle to down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'string',char(8595))

% --- Executes during object creation, after setting all properties.
function add_CreateFcn(hObject, eventdata, handles)
% hObject    handle to add (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'string',char(8594))

% --- Executes during object creation, after setting all properties.
function remove_CreateFcn(hObject, eventdata, handles)
% hObject    handle to remove (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'string',char(8592))

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
