function varargout = CommandCenter(varargin)
% CommandCenter
% CommandCenter [flags]
% CommandCenter([name,value])
% CommandCenter([flag1],[name1,value1],[flag2],[name2,value2])
% Flags (should be char vectors and order does not matter):
%   debug: Sets logger to DEBUG and starts logger on startup.
%   reset: Removes any previously loaded modules.
% Name/Value Pairs (order of pairs does not matter). Default values in parentheses:
%   namespace: ('') Prepend char vector to namespaces for debugging purposes.
%
% -> Note, order of name/value pairs and flags does not matter
% -> Note `CommandCenter string1 string2` is equivalent to `CommandCenter('string1','string2')`
%
% COMMANDCENTER MATLAB code for CommandCenter.fig
%      COMMANDCENTER, by itself, creates a new COMMANDCENTER or raises the existing
%      singleton*.
%
%      H = COMMANDCENTER returns the handle to a new COMMANDCENTER or the handle to
%      the existing singleton*.
%
%      COMMANDCENTER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in COMMANDCENTER.M with the given input arguments.
%
%      COMMANDCENTER('Property','Value',...) creates a new COMMANDCENTER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before CommandCenter_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to CommandCenter_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help CommandCenter

% Last Modified by GUIDE v2.5 28-Apr-2021 20:31:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CommandCenter_OpeningFcn, ...
                   'gui_OutputFcn',  @CommandCenter_OutputFcn, ...
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

function [tf,varargin] = parseInput(varargin,arg)
% Check for existance of string in cell array and return cell array with arg removed
mask = strcmpi(varargin,arg);
tf = any(mask); % If varargin is empty `any([])` is false as expected
varargin = varargin(~mask);

% --- Executes just before CommandCenter is made visible.
function CommandCenter_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to CommandCenter (see VARARGIN)
if strcmp(hObject.Visible,'on')
    % Means it already exists, so do nothing
    return
end
% Check compatibility
if verLessThan('matlab','9.4') % R2018a
    delete(hObject);
    msg = ['You are running a MATLAB version less than R2018a (version 9.4). ',...
           'You may encounter unexpected errors due to a major update in ',...
           'implicit superclass constructor calls.' newline newline...
           'Update to a newer release >= R2018a!'];
    errordlg(msg);
    throwAsCaller(MException('CommandCenter:version',msg));
end
MATLAB_prefs = fullfile(prefdir,'matlabprefs.mat');
key = 'ROYZNcVBgWkT8xiwcg5m2Nn9Gb4EAegF2XEN1i5adWD';  % CC key (helps avoid spam)
[path,~,~] = fileparts(mfilename('fullpath'));
% Check for lock file
if exist(fullfile(path,'.lock'),'file')
    lock = fullfile(path,'.lock');
    
    answer = questdlg(sprintf('Found a lock file, are you sure there is no other CommandCenter instance running?\n%s', lock),...
                                '.lock File Found', 'Continue With This New Instance', 'Oops, An Old Instance Is Running', 'Oops, An Instance Exists');
                            
    switch answer
        case 'Continue With This Instance'
        case 'Oops, An Instance Exists'
            delete(hObject);
            error('Truly, one CommandCenter is more than enough.')
    end
end
fclose(fopen(fullfile(path,'.lock'), 'w'));

% Allocate names in case error for things that need to be cleaned up
loading_fig = [];
handles.logger = [];
handles.inactivity_timer = [];
handles.GitPanel = [];
try
    % Check integrity of pref file
    try
        getpref();
    catch err
        if strcmp(err.identifier,'MATLAB:load:notBinaryFile') && exist(fullfile(path,'.matlabprefs.mat.backup'),'file')
            backup = dir(fullfile(path,'.matlabprefs.mat.backup'));
            original = dir(MATLAB_prefs);
            backup_info = sprintf('%s (%i B) %s',backup.date,backup.bytes,fullfile(backup.folder,backup.name));
            original_info = sprintf('%s (%i B) %s',original.date,original.bytes,fullfile(original.folder,original.name));
            resp = questdlg(sprintf(['Error loading MATLAB''s pref file. May have been corrupted on a force quit. ' ...
                'A backup file was found, would you like to restore it?\n\nBackup: %s\n\nOriginal: %s'],...
                backup_info,original_info),mfilename,'Yes','Cancel','Yes');
            if strcmp(resp,'Yes')
                [msg,msgID] = copyfile(fullfile(path,'.matlabprefs.mat.backup'),MATLAB_prefs);
                if ~isempty(msg)
                    error(msgID,msg);
                end
            else
                error('COMMANDCENTER:prefs_corrupted','Cannot continue with corrupted pref file.')
            end
        else
            rethrow(err);
        end
    end
    
    % Parse inputs flags
    assert(all(cellfun(@ischar,varargin)),'All inputs provided to CommandCenter must be strings')
    [debug,varargin] = parseInput(varargin,'debug');
    [reset,varargin] = parseInput(varargin,'reset');
    p = inputParser();
    p.addParameter('namespace','',@ischar);
    p.parse(varargin{:}); % p.Results has 
    % Prepare state based on inputs
    loggerStartState = 'off';
    debugLevel = Base.Logger.INFO;
    if debug
        loggerStartState = 'on';
        debugLevel = Base.Logger.DEBUG;
    end
    if reset
        % Remove Manager prefs which is responsible for remembering which
        % modules were loaded for each manager
        if ispref('Manager')
            rmpref('Manager');
        end
    end
    setappdata(hObject,'namespace_prefix',p.Results.namespace);
    
    % Update path
    warning('off','MATLAB:dispatcher:nameConflict');  % Overloaded methods
    if ~exist(fullfile(path,'dbquit.m'),'file')
        copyfile(fullfile(path,'dbquit_disabled.m'),fullfile(path,'dbquit.m'));
    end
    [loading_fig, textH] = Base.loadingFigure(fullfile(path, 'static', 'load.png'),...
        'CommandCenter Loading');
    set(textH,'String', 'Adding Paths'); drawnow;
    addpath(path)
    addpath(genpath(fullfile(path,'overload_builtin')))
    addpath(genpath(fullfile(path,'HelperFunctions')))
    addpath(genpath(fullfile(path,'VerdiClient')))
    addpath(genpath(fullfile(path,'slackAPI')))
    addpath(fullfile(path,'Modules'))
    addpath(fullfile(path,'Modules','Managers'))
    
    % Check Git
    set(textH,'String', 'Checking Git'); drawnow;
    handles.GitPanel = Base.GitPanel(handles.panelGit, handles.figure1);
    
    % Prepare Key
    set(textH,'String', 'Checking Key'); drawnow;
    if exist(fullfile(path,'.unique_key.mat'),'file')
        unique_key = load(fullfile(path,'.unique_key.mat'));
        unique_key = unique_key.unique_key;
    else % First time running on this computer, generate base64 key
        % NOTE: technically not quite base64. ignoring two characters from
        % base64 alphabet that don't work in URL easily: "+" and "/"
        rng('shuffle'); % Use current time to seed
        unique_key = randsample(char([48:57 65:90 97:122]),43,true);
        save(fullfile(path,'.unique_key.mat'),'unique_key');
    end
    
    % Setup Logging
    set(textH,'String', 'Setting Up Logger'); drawnow;
    handles.logger = Base.Logger(mfilename,loggerStartState);
    handles.logger.logLevel = [debugLevel, debugLevel]; % [listbox,textfile]
    handles.logger.URL = sprintf('https://commandcenter-logger.mit.edu/new-log/%s/%s/',key,unique_key); % Set destination URL
    setappdata(hObject,'ALLmodules',{})
    setappdata(hObject,'logger',handles.logger)
    set(handles.file_logger,'checked',handles.logger.visible)
    handles.logger.log(['Using namespace prefix: "',...
        getappdata(hObject,'namespace_prefix') '"'],handles.logger.DEBUG)
    
    if ismac
        handles.panelData.Position(1) = 400;
        handles.LeftPanel.Position(3) = 390;
    end
    
    % Convert panels to scrollPanels
    set(textH,'String', 'Making Panels'); drawnow;
    handles.panelStage =        Base.UIscrollPanel(handles.panelStage);
    handles.panelMetaStage =    Base.UIscrollPanel(handles.panelMetaStage);
    handles.panelImage =        Base.UIscrollPanel(handles.panelImage);
    handles.panelSource =       Base.UIscrollPanel(handles.panelSource);
    handles.panelSweeping =     Base.UIscrollPanel(handles.panelSweeping);
    handles.panelExperiment =   Base.UIscrollPanel(handles.panelExperiment);
    handles.panelDrivers =      Base.UIscrollPanel(handles.panelDrivers);
    handles.panelSave =         Base.UIscrollPanel(handles.panelSave);
    
    % Convert Axes panels to Split panels
    handles.AxesPanels = Base.SplitPanel(handles.panel_im,handles.panel_exp,'horizontal');
    set(handles.AxesPanels.dividerH,'BorderType','etchedin')
    pos = get(handles.panel_im,'position');
    handles.AxesPanelsH = pos(4);  % Necessary to allow GlobalPosition to hang out up there.
    axes_im_only_Callback(hObject,[],handles)  % Set default to just image
    
    set(textH,'String', 'Loading Managers'); drawnow;
    handles.Managers = Base.ManagerContainer;   % So every Manager has same access to other managers
    handles.Managers.Logger = handles.logger;   % Make more accessible
    handles.Managers.handles = handles;         % Give the manager container a handle to figure handles
    
    % Inactivity timer
    handles.Managers.timeout = 30*60;  % seconds
    handles.inactivity_timer = timer('Executionmode','SingleShot',...
        'TimerFcn',@inactivity,'startdelay',handles.Managers.timeout+1,...
        'name','Inactivity Timer','tag',mfilename,'busymode','queue','ObjectVisibility','off');
    handles.inactivity_timer.UserData = handles.Managers;
    
    % Init managers
    set(textH,'String', 'Loading StageManager'); drawnow;
    handles.Managers.Stages = StageManager(handles);


    
    set(textH,'String', 'Loading Experiment Modules');
    handles.Managers.Experiment = ExperimentManager(handles);
    

    set(textH,'String', 'Loading Source Modules'); drawnow;
    handles.Managers.Sources = SourcesManager(handles);
    
    set(textH,'String', 'Loading Paths'); drawnow;
    handles.Managers.Path = PathManager(handles); % Generates its own menu item

    
    set(textH,'String', 'Loading Imaging Modules'); drawnow;
    handles.Managers.Imaging = ImagingManager(handles);
    
    
    set(handles.(handles.Managers.Imaging.set_colormap),'checked','on') % Tags correspond to colormaps
    set(allchild(handles.menu_colormap),'callback',...
    @(hObject,eventdata)CommandCenter('colormap_option_set',hObject,eventdata,guidata(hObject)));
    
    % MetaStageManager has to be the last to load, since it relies on other preferences.
    set(textH,'String', 'Loading MetaStageManager'); drawnow;
    handles.Managers.MetaStage = MetaStageManager(handles);
    
    set(textH,'String', 'Loading Database Modules'); drawnow;
    handles.Managers.DB = DBManager(handles);
    

    set(textH,'String', 'Preparing GUI'); drawnow;
    set(textH,'String', 'Done'); drawnow;
    
%     controls = {handles.panelStage, handles.panelMetaStage, handles.panelImage, handles.panelSource,...
%         handles.panelSweeping, handles.panelExperiment, handles.panelDrivers, handles.panelSave, handles.panelGit};
    controls = {handles.panelGit, handles.panelStage, handles.panelMetaStage, handles.panelImage, handles.panelSource,...
        handles.panelSweeping, handles.panelExperiment, handles.panelDrivers, handles.panelSave};
    Base.UIScrollPanelContainer(handles.LeftPanel, controls, 4);
    
    Base.Resizable(handles.panelStage);
    Base.Resizable(handles.panelMetaStage);
    Base.Resizable(handles.panelImage);
    Base.Resizable(handles.panelSource);
    Base.Resizable(handles.panelSweeping);
    Base.Resizable(handles.panelExperiment);
    Base.Resizable(handles.panelDrivers);
    Base.Resizable(handles.panelSave);
catch err
    delete(loading_fig)
    delete(handles.inactivity_timer)
    delete(handles.logger)
    delete(hObject)
    if exist(fullfile(path,'.lock'),'file')
        delete(fullfile(path,'.lock'));
    end
    errordlg(sprintf('%s\n\nDetails in Command Window',err.message),'Error Loading CommandCenter')
    rethrow(err)
end

% Backup MATLAB prefs file
if exist(MATLAB_prefs,'file')
    [msg,msgID] = copyfile(MATLAB_prefs,fullfile(path,'.matlabprefs.mat.backup'));
    if ~isempty(msg)
        warning(msgID,msg);
        warning([   'If you recently installed a new version of matlab, you can copy your old prefs from:' 13 ...
                    '    C:\Users\<username>\AppData\Roaming\MathWorks\MATLAB\R20<XXx old version>' 13 ...
                    'To:' 13 ...
                    '    C:\Users\<username>\AppData\Roaming\MathWorks\MATLAB\R20<XXx new version>']);
    end
else
    warning('CC:pref_backup_failed','Unable to locate matlabprefs.mat, no backup was made.');
end

% Provide some useful pointers to ManagerContainer class
exists = evalin('base','exist(''managers'')==1&&isa(managers,''Base.ManagerContainer'')&&isvalid(managers)');
if exists
    out = questdlg('Overwrite existing managers variable in base workspace?','CommandCenter','Yes','No','Yes');
    assert(strcmp(out,'Yes'),'CommandCenter needs to overwrite managers to start. Try again.')
end
assignin('base','managers',handles.Managers)
hObject.UserData = handles.Managers;

% Choose default command line output for CommandCenter
handles.output = [];

% Update handles structure
guidata(hObject, handles);
delete(loading_fig)
if strcmp(handles.inactivity_timer.Running,'off')
    % No modules are loaded on startup (otherwise settings called)
    start(handles.inactivity_timer);
end

handles.panelStage.minimize();
handles.panelMetaStage.minimize();
handles.panelImage.minimize();
handles.panelSource.minimize();
handles.panelSweeping.minimize();
handles.panelExperiment.minimize();
handles.panelDrivers.minimize();
handles.panelSave.minimize();
handles.panelMetaStage.setMaximizedHeight(30);
handles.panelImage.setMaximizedHeight(20);


drawnow

function inactivity(timerH,~)
error('Bootstrap to disable inactivity timer.');

[path,~,~] = fileparts(mfilename('fullpath'));
if ~exist(fullfile(path,'dbquit.m'),'file')
    copyfile(fullfile(path,'dbquit_disabled.m'),fullfile(path,'dbquit.m'));
end
routines = {'Reset dbquit fail-safe'};
managers = timerH.UserData;
% Go through manager resets
errs = {};
managerNames = {'DB','Experiment','Sources','Stages','Imaging'};
for i = 1:length(managerNames)
    try
        sub_routines = managers.(managerNames{i}).inactive();
        if ~isempty(sub_routines)
            routines{end+1} = sprintf('%s:\n        %s',class(managers.(managerNames{i})),...
                strjoin(sub_routines,[newline '        ']));
        end
    catch err
        errs{end+1} = sprintf('%s Inactive() Error: %s',managerNames{i},err.message);
    end
end
msg = sprintf('%s has been inactive for more than %i minutes.\n\nRunning reset routines:\n    %s',...
    mfilename,managers.timeout/60,strjoin(routines,[newline '    ']));
managers.handles.logger.log(msg)
managers.handles.logger.sendLogs;  % Send logs to server
warndlg(msg,mfilename,'modal');
managers.inactivity = true;  % Needs to come after calling inactivity methods in modules
if ~isempty(errs)
    error(strjoin(errs,['_________________' newline]))
end

% --- Outputs from this function are returned to the command line.
function varargout = CommandCenter_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

wait = msgbox('Please Wait, CommandCenter is saving modules','help','modal');
delete(findall(wait,'tag','OKButton'))
drawnow
h_list = {handles.Managers};
if (isprop(handles.Managers, 'MetaStage'))
    delete(handles.Managers.MetaStage)
end
for i = 1:numel(h_list)
    for j = 1:numel(h_list{i})
    h = h_list{i}(j);
    if isobject(h)&&isvalid(h)
        delete(h)
    end
    end
end
% Now delete, any leftover modules (drivers usually)
try
    mods = getappdata(hObject,'ALLmodules');
    for i = 1:numel(mods)
        if isvalid(mods{i})
            handles.logger.log(sprintf('(Unmanaged) - Destroying <a href="matlab: opentoline(%s,1)">%s</a>',which(class(mods{i})),class(mods{i})))
            delete(mods{i})
        end
    end
catch err
    warning(sprintf("Failed to delete handles %s", err.message));
end 
stop(handles.inactivity_timer);
delete(handles.inactivity_timer)
handles.logger.sendLogs;  % Send logs to server
delete(wait)
delete(hObject)
delete(handles.logger)
[path,~,~] = fileparts(mfilename('fullpath'));
if exist(fullfile(path,'dbquit.m'),'file') % Disable override
    delete(fullfile(path,'dbquit.m'));
end
% Backup MATLAB prefs file
MATLAB_prefs = fullfile(prefdir,'matlabprefs.mat');
if exist(MATLAB_prefs,'file')
    [msg,msgID] = copyfile(MATLAB_prefs,fullfile(path,'.matlabprefs.mat.backup'));
    if ~isempty(msg)
        warning(msgID,msg);
    end
else
    warning('CC:pref_backup_failed','Unable to locate matlabprefs.mat, no backup was made.');
end

if exist(fullfile(path,'.lock'),'file')
    delete(fullfile(path,'.lock'));
end

% --- Executes when figure1 is resized.
function figure1_SizeChangedFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
temp = get(handles.figure1,'units');
set(handles.figure1,'units','pixels')
bounds = get(handles.figure1,'position');
width = bounds(3);
height = bounds(4);
set(handles.figure1,'position',[bounds(1:2) width height]);
bounds = get(handles.figure1,'position');
dist = 10; % pixels
% LeftPanel
leftpanel = get(handles.LeftPanel,'Position');
set(handles.LeftPanel,'units','pixels')
set(handles.LeftPanel,'Position',[dist dist leftpanel(3) bounds(4)-2*dist]);
leftpanel = get(handles.LeftPanel,'Position');
% panelData
set(handles.panelData,'units','pixels')
set(handles.panelData,'Position',[leftpanel(3)+dist*2 dist bounds(3)-(leftpanel(3)+dist*3) bounds(4)-2*dist]);
datapanel = get(handles.panelData,'Position');
set(handles.global_panel,'units','pixels')
globalPanel = get(handles.global_panel,'position');
width = globalPanel(3);
height = globalPanel(4);
x = datapanel(3)/2-width/2;
y = datapanel(4) - height;
set(handles.global_panel,'position',[x y width height]);
set(handles.figure1,'units',temp)

% --- Executes on selection change in figureDisplay.
function figureDisplay_Callback(hObject, eventdata, handles)
% hObject    handle to figureDisplay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes during object creation, after setting all properties.
function figureDisplay_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figureDisplay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function file_Callback(hObject, eventdata, handles)
% hObject    handle to file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.file_logger,'checked',handles.logger.visible)

% --------------------------------------------------------------------
function file_open_im_Callback(hObject, eventdata, handles)
% hObject    handle to file_open_im (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
path = handles.Managers.Imaging.get_im_path;
if path
    handles.Managers.Imaging.open_im(path);
end

% --------------------------------------------------------------------
function file_logger_Callback(hObject, eventdata, handles)
% hObject    handle to file_logger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
state = handles.logger.visible;
if strcmp(state,'off')
    NewState = 'on';
else
    NewState = 'off';
end
handles.logger.visible = NewState;

% --------------------------------------------------------------------
function menu_stage_Callback(hObject, eventdata, handles)
% hObject    handle to menu_stage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.Stages.getAvail(hObject);

% --------------------------------------------------------------------
function menu_imaging_Callback(hObject, eventdata, handles)
% hObject    handle to menu_imaging (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.Imaging.getAvail(hObject);

% --------------------------------------------------------------------
function menu_sources_Callback(hObject, eventdata, handles)
% hObject    handle to menu_sources (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.Sources.getAvail(hObject);

% --------------------------------------------------------------------
function menu_experiments_Callback(hObject, eventdata, handles)
% hObject    handle to menu_experiments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.Experiment.getAvail(hObject);

% --------------------------------------------------------------------
function menu_saving_Callback(hObject, eventdata, handles)
% hObject    handle to menu_saving (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.DB.getAvail(hObject);

% --------------------------------------------------------------------
function menu_settings_Callback(hObject, eventdata, handles)
% hObject    handle to menu_settings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function Camera_Calibration_Callback(hObject, eventdata, handles)
% hObject    handle to Camera_Calibration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.Imaging.calibrate;

% --------------------------------------------------------------------
function menu_axes_Callback(hObject, eventdata, handles)
% hObject    handle to menu_axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function axes_horizontal_Callback(hObject, eventdata, handles)
% hObject    handle to axes_horizontal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.panel_im,'position',[0 0 0.5 handles.AxesPanelsH],'visible','on')
set(handles.panel_exp,'position',[0.5 0 0.5 handles.AxesPanelsH],'visible','on')
handles.AxesPanels.enable = 'on';
handles.AxesPanels.type = 'horizontal';

% --------------------------------------------------------------------
function axes_vertical_Callback(hObject, eventdata, handles)
% hObject    handle to axes_vertical (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
h = handles.AxesPanelsH;
set(handles.panel_im,'position',[0 0 1 0.5*h],'visible','on')
set(handles.panel_exp,'position',[0 0.5*h 1 0.5*h],'visible','on')
handles.AxesPanels.enable = 'on';
handles.AxesPanels.type = 'vertical';

% --------------------------------------------------------------------
function axes_exp_only_Callback(hObject, eventdata, handles)
% hObject    handle to axes_exp_only (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.AxesPanels.enable = 'off';
set(handles.panel_exp,'position',[0 0 1 handles.AxesPanelsH],'visible','on')
set(handles.panel_im,'position',[0 0 1 handles.AxesPanelsH],'visible','off')

% --------------------------------------------------------------------
function axes_im_only_Callback(hObject, eventdata, handles)
% hObject    handle to axes_im_only (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.AxesPanels.enable = 'off';
set(handles.panel_im,'position',[0 0 1 handles.AxesPanelsH],'visible','on')
set(handles.panel_exp,'position',[0 0 1 handles.AxesPanelsH],'visible','off')

% --- Executes during object creation, after setting all properties.
function stage_setx_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stage_setx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function stage_sety_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stage_sety (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function stage_setz_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stage_setz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function stage_negX_CreateFcn(hObject, eventdata, handles)
set(hObject,'string',char(8592))
% --- Executes during object creation, after setting all properties.
function stage_posX_CreateFcn(hObject, eventdata, handles)
set(hObject,'string',char(8594))
% --- Executes during object creation, after setting all properties.
function stage_posY_CreateFcn(hObject, eventdata, handles)
set(hObject,'string',char(8593))
% --- Executes during object creation, after setting all properties.
function stage_negY_CreateFcn(hObject, eventdata, handles)
set(hObject,'string',char(8595))


% --- Executes during object creation, after setting all properties.
function stage_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stage_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function sources_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sources_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function menu_colormap_Callback(hObject, eventdata, handles)
% hObject    handle to menu_colormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function colormap_option_set(hObject,eventdata,handles)
handles.Managers.Imaging.set_colormap = get(hObject,'tag');
set(allchild(handles.menu_colormap),'checked','off')
set(hObject,'checked','on')
colormap(handles.figure1,handles.Managers.Imaging.set_colormap)
guidata(hObject,handles)

% --- Executes during object creation, after setting all properties.
function image_ROI_CreateFcn(hObject, eventdata, handles)
% hObject    handle to image_ROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject, 'Data', cell(2));
set(hObject, 'RowName', {'x', 'y'}, 'ColumnName', {'Start', 'Stop'});
pos = get(hObject,'position');
extent = get(hObject,'extent');
set(hObject,'position',[pos(1:2) extent(3:4)])


% --- Executes during object creation, after setting all properties.
function saving_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to saving_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function colorbar_toggle_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to colorbar_toggle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if strcmp(get(hObject,'state'),'on')
    colorbar(handles.axImage)
else
    colorbar(handles.axImage,'off')
end



% --- Executes on button press in clim_lock.
function clim_lock_Callback(hObject, eventdata, handles)
% hObject    handle to clim_lock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of clim_lock



function clim_low_Callback(hObject, eventdata, handles)
% hObject    handle to clim_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of clim_low as text
%        str2double(get(hObject,'String')) returns contents of clim_low as a double


% --- Executes during object creation, after setting all properties.
function clim_low_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clim_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function clim_high_Callback(hObject, eventdata, handles)
% hObject    handle to clim_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of clim_high as text
%        str2double(get(hObject,'String')) returns contents of clim_high as a double


% --- Executes during object creation, after setting all properties.
function clim_high_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clim_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in image_select.
function image_select_Callback(hObject, eventdata, handles)
% hObject    handle to image_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns image_select contents as cell array
%        contents{get(hObject,'Value')} returns selected item from image_select


% --- Executes during object creation, after setting all properties.
function image_select_CreateFcn(hObject, eventdata, handles)
% hObject    handle to image_select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function manager_settings_Callback(hObject, eventdata, handles)
% hObject    handle to manager_settings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function db_Callback(hObject, eventdata, handles)
% hObject    handle to db (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.propedit(handles.Managers.DB);

% --------------------------------------------------------------------
function experiment_Callback(hObject, eventdata, handles)
% hObject    handle to experiment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.propedit(handles.Managers.Experiment);

% --------------------------------------------------------------------
function sources_Callback(hObject, eventdata, handles)
% hObject    handle to sources (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.propedit(handles.Managers.Sources);

% --------------------------------------------------------------------
function stage_Callback(hObject, eventdata, handles)
% hObject    handle to stage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.propedit(handles.Managers.Stages);

% --------------------------------------------------------------------
function imaging_Callback(hObject, eventdata, handles)
% hObject    handle to imaging (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.propedit(handles.Managers.Imaging);


% --------------------------------------------------------------------
function reset_Callback(hObject, eventdata, handles)
% hObject    handle to reset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(handles.figure1);
CommandCenter;


% --------------------------------------------------------------------
function new_experiment_Callback(hObject, eventdata, handles)
% hObject    handle to new_experiment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
name = inputdlg(sprintf('Experiment name (must be valid MATLAB filename)\n ->Note it is not trivial to change the name after creation!'),...
    'New Experiment Module',1,{'my_experiment'});
if ~isempty(name)
    name = strrep(name{1},' ','_');
    Modules.Experiment.new(name);
end


% --------------------------------------------------------------------
function git_pull_master_Callback(hObject, eventdata, handles)
% hObject    handle to git_pull_master (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
CCpath = fileparts(mfilename('fullpath'));
info = getGitInfo(CCpath);
if ~strcmp(info.branch,'master')
    errordlg('This only works if you are on master already.',mfilename);
    return
end
if isempty(info.remote)
    errordlg('This only works if you have a remote setup!',mfilename);
    return
end
% Get confirmation
response = questdlg(strjoin({'This will close CommandCenter and unlock everything locked in memory.',...
    'If you have anything you want to save, cancel this and save first.',...
    'This is in beta, and you should check output in console to be sure it worked!',...
    sprintf('\n\nContinue?')},' '),mfilename,'Yes','Cancel','Yes');
if strcmp(response,'Yes')
    try
        recovery_failure = false; % Used to confirm git merge --abort worked, but notify after fprintf
        old_wd = cd(fullfile(CCpath,'HelperFunctions','ThirdParty')); % Nice safe folder in repo that doesnt have locked files or packages and home of git
        close(handles.figure1); % From here on, all handles are stale
        munlockAll;
        % Remove items from path
        CC_on_path = intersect(strsplit(path(),';'),strsplit(genpath(CCpath),';')); % All CC paths that are on MATLAB's path
        rmpath(strjoin(CC_on_path,';'));
        % Git stuff
        out = git('pull');
        if contains(out,'Cannot merge')
            errordlg(out,'git pull')
        elseif contains(out,'CONFLICT')
            abort = git('merge --abort'); % Reset to where it was
            out = sprintf('%s\n\nGit merge --abort output:\n\n%s',out,abort);
            errordlg(sprintf('%s\n\nCC aborted pull:\n%s',out,abort),'git pull')
            new_info = getGitInfo(CCpath);
            if ~strcmp(info.hash,new_info.hash)
                recovery_failure = true;
            end
        else
        end
        fprintf('\nGit pull output:\n\n%s\n\n',out); % Print to window as well
        assert(~recovery_failure,'Failed to run "git merge --abort" to undo attempted "git pull". Confirm state in console manually.')
        % Relaunch CC, restore path and pwd
        addpath(CC_on_path{:});
        cd(old_wd);
        CommandCenter;
    catch err % restore path and pwd
        cd(old_wd);
        addpath(CC_on_path{:});
        rethrow(err);
    end
    
end


% --------------------------------------------------------------------
function send_logs_Callback(hObject, eventdata, handles)
% hObject    handle to send_logs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.logger.sendLogs;


% --------------------------------------------------------------------
function file_load_image_Callback(hObject, eventdata, handles)
% hObject    handle to file_load_image (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
path = handles.Managers.Imaging.get_im_path;
if path
    handles.Managers.Imaging.load_im(path);
end


% --------------------------------------------------------------------
function ui_module_build_Callback(hObject, eventdata, handles)
% hObject    handle to ui_module_build (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Base.Module.uibuild;


% --------------------------------------------------------------------
function menu_metastage_Callback(hObject, eventdata, handles)
% hObject    handle to menu_metastage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.Managers.MetaStage.getAvail(hObject);


% --------------------------------------------------------------------
function menu_sweeping_Callback(hObject, eventdata, handles)
% hObject    handle to menu_sweeping (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function menu_drivers_Callback(hObject, eventdata, handles)
% hObject    handle to menu_drivers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
