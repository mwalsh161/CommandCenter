classdef mcUserInput < mcSavableClass
% mcUserInputGUI returns the uitabgroup reference that contains three tabs:
%   - Goto:         buttons and edit fields to control the axes.
%   - User Input:   click buttons that take the place of arrows on a keyboard and field to customize
%                   how the joystick and keyboard move the axes.
%
%   obj = mcUserInput()                 % 
%   obj = mcUserInput(config)           % 
%   obj = mcUserInput('config.mat')     % 
%
% Status: Finished; Mostly commented.
    
    properties
%         config = [];            % Defined in mcSavableClass. All static variables (e.g. valid range) go in config.
        
        gui = [];               % Variables for the gui.
        
        wp = [];
        
        mode = 1;               % userInput mode, i.e. which set of axes the commands are sent to.
    end
      
    methods (Static)  
        function config = defaultConfig()
%             config = mcUserInput.diamondConfig();
            config = mcUserInput.lossTestConfig();
        end
        function config = lossTestConfig()
            config.name =               'Default User Input';
            
            configPiezoXL = mcaDAQ.piezoNanoMaxConfig();    configPiezoXL.name = 'Piezo X L'; configPiezoXL.chn = 'ao0';       % Customize all of the default configs...
            configPiezoXR = mcaDAQ.piezoNanoMaxConfig();    configPiezoXR.name = 'Piezo X R'; configPiezoXR.chn = 'ao1';
            configPiezoYL = mcaDAQ.piezoNanoMaxConfig();    configPiezoYL.name = 'Piezo Y L'; configPiezoYL.chn = 'ao2';
            configPiezoYR = mcaDAQ.piezoNanoMaxConfig();    configPiezoYR.name = 'Piezo Y R'; configPiezoYR.chn = 'ao3';
            
            configStepperF = mcaMotorArduino.stepperConfig(1);  configStepperF.name = 'Stepper Local';  configStepperF.line = 2;
            configStepperC = mcaMotorArduino.stepperConfig(.5); configStepperC.name = 'Stepper Global'; configStepperC.line = 1;
            
            config.axesGroups = { {'Left',      mcaDAQ(configPiezoXL),  mcaDAQ(configPiezoYL), mcaMotorArduino(configStepperF) }, ...     % Arrange the axes into sets of {name, axisX, axisY, axisZ}.
                                  {'Right',     mcaDAQ(configPiezoXR),  mcaDAQ(configPiezoYR), mcaMotorArduino(configStepperF) }, ...
                                  {'Steppers',  mcaMotorArduino(configStepperC),    mcaMotorArduino(configStepperF) } };
                              
            config.numGroups = length(config.axesGroups);
            
            config.joyEnabled = false;
        end
        function config = diamondConfig()
            config.name =               'Default User Input';
            
            configPiezoX = mcaDAQ.piezoConfig();    configPiezoX.name = 'Piezo X'; configPiezoX.chn = 'ao0';       % Customize all of the default configs...
            configPiezoY = mcaDAQ.piezoConfig();    configPiezoY.name = 'Piezo Y'; configPiezoY.chn = 'ao1';
            configPiezoZ = mcaDAQ.piezoZConfig();   configPiezoZ.name = 'Piezo Z'; configPiezoZ.chn = 'ao2';
            
            configMicroX = mcaMicro.microConfig();  configMicroX.name = 'Micro X'; configMicroX.port = 'COM5';
            configMicroY = mcaMicro.microConfig();  configMicroY.name = 'Micro Y'; configMicroY.port = 'COM6';
            
%             configGalvoX = mcaDAQ.galvoConfig();    configGalvoX.name = 'Galvo X'; configGalvoX.dev = 'cDAQ1Mod1'; configGalvoX.chn = 'ao0';
%             configGalvoY = mcaDAQ.galvoConfig();    configGalvoY.name = 'Galvo Y'; configGalvoY.dev = 'cDAQ1Mod1'; configGalvoY.chn = 'ao1';

            configV1 = mcaDAQ.PIE616Config();       configV1.name = 'H Voltage 1';  configV1.chn = 'ao0';
            configV2 = mcaDAQ.PIE616Config();       configV2.name = 'H Voltage 2';  configV2.chn = 'ao1';
            configV3 = mcaDAQ.PIE616Config();       configV3.name = 'H Voltage 3';  configV3.chn = 'ao2';

            configGalvoX = mcaDAQ.galvoXConfig();
            configGalvoY = mcaDAQ.galvoYConfig();
            
%             configDoor =   mcaDAQ.digitalConfig();   configDoor.name =  'Door LED'; configDoor.chn =  'Port0/Line7';
            configGreen =  mcaDAQ.greenConfig();
            configOD =     mcaDAQ.greenOD2Config();
            configRed =    mcaDAQ.redConfig();
            configRedDig = mcaDAQ.redDigitalConfig();
            
            flipConfig = mcaArduino.flipMirrorConfig();
%             flipConfig =        mcaDAQ.digitalConfig();
%             flipConfig.chn = 	'Port0/Line1';
%             flipConfig.name = 	'Flip Mirror';
            
            config.axesGroups = { {'Micros',    mcaMicro(configMicroX), mcaMicro(configMicroY), mcaDAQ(configPiezoZ) }, ...     % Arrange the axes into sets of {name, axisX, axisY, axisZ}.
                                  {'Piezos',    mcaDAQ(configPiezoX),   mcaDAQ(configPiezoY),   mcaDAQ(configPiezoZ) }, ...
                                  {'Galvos',    mcaDAQ(configGalvoX),   mcaDAQ(configGalvoY),   mcaDAQ(configPiezoZ) }, ...
                                  {'Green',     mcaDAQ(configGreen),    mcaDAQ(configOD),       mcaArduino(flipConfig) }, ...
                                  {'Red',       mcaDAQ(configRedDig),   mcaDAQ(configRed),      mcaArduino(flipConfig) } };
                              
            config.numGroups = length(config.axesGroups);
            
            config.joyEnabled = false;
            
            config.axesGroups{4}{4}.open(); % Open the flip mirror (why?)
        end
        function config = brynnConfig()
            config.name =               'Default User Input';
            
            configMicroX = mcaMicro.microXBrynnConfig();
            configMicroY = mcaMicro.microYBrynnConfig();

            configGalvoX = mcaDAQ.galvoXBrynnConfig();
            configGalvoY = mcaDAQ.galvoYBrynnConfig();
            
            configObjZ = mcaEO.brynnObjConfig();
            
            config.axesGroups = { {'Micrometers',           mcaMicro(configMicroX), mcaMicro(configMicroY), mcaEO(configObjZ) }, ...     % Arrange the axes into sets of {name, axisX, axisY, axisZ}.
                                  {'Galvos',                mcaDAQ(configGalvoX),   mcaDAQ(configGalvoY),   mcaEO(configObjZ) }, ... 
                                  {[char(955) '/2 Plate'],  mcaDAQ(configGalvoX),   mcaDAQ(configGalvoY),  mcaHwpRotator } };
                              
            config.numGroups = length(config.axesGroups);
            
            config.joyEnabled = false;
        end
        function config = diamondConfigHV()
            % High Voltage configuration for the diamond microscope, in which
            % the piezos, the micrometers, the high voltage outputs, and the lasers are the axes
            
            config.name =               'Default (+HV) User Input';
            
            configPiezoX = mcaDAQ.piezoConfig();    configPiezoX.name = 'Piezo X'; configPiezoX.chn = 'ao0';       % Customize all of the default configs...
            configPiezoY = mcaDAQ.piezoConfig();    configPiezoY.name = 'Piezo Y'; configPiezoY.chn = 'ao1';
            configPiezoZ = mcaDAQ.piezoZConfig();   configPiezoZ.name = 'Piezo Z'; configPiezoZ.chn = 'ao2';
            
            configMicroX = mcaMicro.microConfig();  configMicroX.name = 'Micro X'; configMicroX.port = 'COM5';
            configMicroY = mcaMicro.microConfig();  configMicroY.name = 'Micro Y'; configMicroY.port = 'COM6';
            
%             configGalvoX = mcaDAQ.galvoConfig();    configGalvoX.name = 'Galvo X'; configGalvoX.dev = 'cDAQ1Mod1'; configGalvoX.chn = 'ao0';
%             configGalvoY = mcaDAQ.galvoConfig();    configGalvoY.name = 'Galvo Y'; configGalvoY.dev = 'cDAQ1Mod1'; configGalvoY.chn = 'ao1';

            configV1 = mcaDAQ.PIE616Config();       configV1.name = 'H Voltage 1';  configV1.chn = 'ao0';
            configV2 = mcaDAQ.PIE616Config();       configV2.name = 'H Voltage 2';  configV2.chn = 'ao1';
            configV3 = mcaDAQ.PIE616Config();       configV3.name = 'H Voltage 3';  configV3.chn = 'ao2';

            configGalvoX = mcaDAQ.galvoConfig();    configGalvoX.name = 'Galvo X'; configGalvoX.dev = 'cDAQ1Mod1'; configGalvoX.chn = 'ao0';
            configGalvoY = mcaDAQ.galvoConfig();    configGalvoY.name = 'Galvo Y'; configGalvoY.dev = 'cDAQ1Mod1'; configGalvoY.chn = 'ao1';
            
            configDoor =   mcaDAQ.digitalConfig();   configDoor.name =  'Door LED'; configDoor.chn =  'Port0/Line7';
            configGreen =  mcaDAQ.greenConfig();
            configRed =    mcaDAQ.redConfig();
            
            flipConfig =        mcaDAQ.digitalConfig();
            flipConfig.chn = 	'Port0/Line1';
            flipConfig.name = 	'Flip Mirror';
            
            config.axesGroups = { {'Micrometers',   mcaMicro(configMicroX), mcaMicro(configMicroY), mcaDAQ(configPiezoZ) }, ...     % Arrange the axes into sets of {name, axisX, axisY, axisZ}.
                                  {'Piezos',        mcaDAQ(configPiezoX),   mcaDAQ(configPiezoY),   mcaDAQ(configPiezoZ) }, ...
                                  {'High Voltage',  mcaDAQ(configV1),       mcaDAQ(configV2),       mcaDAQ(configV3) }, ...
                                  {'Lasers',        mcaDAQ(configDoor),     mcaDAQ(configGreen),    mcaDAQ(flipConfig) } };                 % Eventually put red power on here...
                              
            config.axesGroups{4}{4}.open(); 
                              
            config.numGroups = length(config.axesGroups);
            
            config.joyEnabled = false;
            
%             config.axesGroups = { {'Piezos',        mcAxis('configPiezoX.mat'), mcAxis('configPiezoY.mat'), mcAxis('configPiezoZ.mat') }, ...
%                                   {'Micrometers',   mcAxis('configMicroX.mat'), mcAxis('configMicroY.mat'), mcAxis('configPiezoZ.mat') }, ...
%                                   {'Galvometers',   mcAxis('configGalvoX.mat'), mcAxis('configGalvoY.mat'), mcAxis('configPiezoZ.mat') } };
        end
    end
    
    methods
        function obj = mcUserInput(varin)
            switch nargin
                case 0
                    obj.config = mcUserInput.defaultConfig();   % If no config is given, assume default config.
                case 1
                    obj.config = varin;
%                     obj.interpretConfig(varin);                 % Otherwise, use the given config (struct or file), where .interpretConfig() is inherited from mcSavableClass.
                otherwise
                    error('NotImplemented');
            end
            
            obj.makeGUI();                                      % Then make the GUI.
        end
        
        function makeGUI(varin)
            fw = 300;               % Figure width
            fh = 500;               % Figure height
            
            pp = 5;                 % Panel padding
            pw = fw - 25;           % Panel width
            ph = 200;               % Panel height
            
            bh = 20;                % Button Height
            
            switch nargin
                case 1
                    obj = varin;
                    mcInstrumentHandler.setGlobalWindowKeyPressFcn(@obj.keyPressFunction);
                    
                    f = mcInstrumentHandler.createFigure(obj, 'saveopen');
                    
                    f.Resize =      'off';
                    f.Position =    [100, 100, fw, fh];
                    f.Visible =     'off';
                    f.MenuBar =     'none';
%                     f.ToolBar =     'none';
                    
                    units = 'normalized';
                    pos = [0 0 1 1];
                case 3
                    obj = varin{1};
                    mcInstrumentHandler.setGlobalWindowKeyPressFcn(@obj.keyPressFunction);
                    
                    f =   varin{2};
                    units = 'pixels';
                    pos = varin{3};
                otherwise
                    error('Use either mcUserInput.makeGUI() or mcUserInput.makeGUI(f, position)');
            end
            
            obj.gui.f = f;
            obj.gui.f.CloseRequestFcn = @obj.closeRequestFcn;
            
            obj.gui.tabgroup =  uitabgroup('Parent', f, 'Units', units, 'Position', pos);
            obj.gui.tabGoto =       uitab('Parent', obj.gui.tabgroup, 'Title', 'Goto', 'Units', 'pixels');
            obj.gui.tabInputs =     uitab('Parent', obj.gui.tabgroup, 'Title', 'User Input', 'Units', 'pixels');
%             obj.gui.tabJoystick =   uitab('Parent', obj.gui.tabgroup, 'Title', 'Joystick', 'Units', 'pixels');
            
            
            %%%%%%%%%% GOTO TAB %%%%%%%%%%
            obj.gui.gotoPanels = {};
            
            pause(.01);
            
            tabHeight = obj.gui.tabGoto.Position(4);
            tabHeightInput = obj.gui.tabInputs.Position(4) - 3.5*bh;
            
%             obj.config.axesGroups
            
            obj.config.axesList = {};
            
            for ii = 1:obj.config.numGroups
                obj.gui.gotoPanels{ii} =  uipanel('Parent', obj.gui.tabGoto, 'Title', [num2str(ii) ' : ' obj.config.axesGroups{ii}{1}], 'Units', 'pixels', 'ButtonDownFcn', {@obj.setUserInputMode, ii});
                obj.gui.inputPanels{ii} = uipanel('Parent', obj.gui.tabInputs, 'Units', 'pixels', 'Position', [pp + (ii-1)*((pw-2*pp)/obj.config.numGroups + pp), tabHeightInput, pw/obj.config.numGroups, bh], 'ButtonDownFcn', {@obj.setUserInputMode, ii});
                uicontrol('Parent', obj.gui.inputPanels{ii}, 'Style', 'text', 'String', [num2str(ii) ' : ' obj.config.axesGroups{ii}{1}], 'Units', 'normalized', 'Position', [0 0 1 1], 'Enable', 'inactive', 'ButtonDownFcn', {@obj.setUserInputMode, ii});
                
                y = pp + 2*bh;
                
                for jj = 2:(length(obj.config.axesGroups{ii}))
                    tf = obj.makeAxisControls(obj.config.axesGroups{ii}{jj}, obj.gui.gotoPanels{ii}, y, ii);
                    
                    if tf
                        y = y - bh;
                    end
                end
                
                for jj = 2:(length(obj.config.axesGroups{ii}))
                    if sum(cellfun(@(a)(a == obj.config.axesGroups{ii}{jj}), obj.config.axesList)) == 0
                        obj.config.axesList{length(obj.config.axesList) + 1} = obj.config.axesGroups{ii}{jj};
                    end
                end
                
                tabHeight = tabHeight - y -5*bh;
                obj.gui.gotoPanels{ii}.Position = [pp+1, tabHeight - 2*bh, pw, y + 5*bh - pp];
            end
            
            obj.refreshUserInputMode();
            
            sendEditsToTopOfUIStack(obj.gui.f);
            
            %%%%%%%%%% USER INPUTS TAB %%%%%%%%%%
            tabHeight = obj.gui.tabInputs.Position(4) - 5*bh;
            
            bbh = (pw)/7; % Big button height
            
            obj.gui.keyUp =     uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', '(Shift for x10 and Alt for x1/10 speed)', 'Position', [0, tabHeight, pw, bh], 'Callback', {@obj.userAction_Callback, 2, 1});
            
%             obj.gui.keyUp =     uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', 'A', 'Position', [2*bbh, tabHeight - 1*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 2, 1});
%             obj.gui.keyLeft =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', '<', 'Position', [1*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 1, -1});
%             obj.gui.keyDown =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', 'V', 'Position', [2*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 2, -1});
%             obj.gui.keyRight =  uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', '>', 'Position', [3*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 1, 1});
            
            obj.gui.keyUp =     uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8679), 'Position', [2*bbh, tabHeight - 1*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 2, 1});
            obj.gui.keyLeft =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8678), 'Position', [1*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 1, -1});
            obj.gui.keyDown =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8681), 'Position', [2*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 2, -1});
            obj.gui.keyRight =  uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8680), 'Position', [3*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 1, 1});
            
%             obj.gui.keyPlus =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', '+', 'Position', [5*bbh, tabHeight - 1*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, 1});
%             obj.gui.keyMinus =  uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', '-', 'Position', [5*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, -1});
            
            obj.gui.keyPlus =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(10752), 'Position', [5*bbh, tabHeight - 1*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, 1});
            obj.gui.keyMinus =  uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(10754), 'Position', [5*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, -1});
            
%             obj.gui.keyPlus =   uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8857), 'Position', [5*bbh, tabHeight - 1*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, 1});
%             obj.gui.keyMinus =  uicontrol('Parent', obj.gui.tabInputs, 'Style', 'push', 'String', char(8855), 'Position', [5*bbh, tabHeight - 2*bbh, bbh, bbh], 'Callback', {@obj.userAction_Callback, 3, -1});
            
            obj.gui.keylist = [obj.gui.keyLeft, obj.gui.keyRight, obj.gui.keyDown, obj.gui.keyUp, obj.gui.keyMinus, obj.gui.keyPlus];
            
%             uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', 'Keyboard', 'Position', [pw/3,   tabHeight - 2*bbh - 2*bh, pw/3, bh]);
%             uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', 'Joystick', 'Position', [2*pw/3, tabHeight - 2*bbh - 2*bh, pw/3, bh]);
            
            uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', 'Enable:', 'Position', [0,   tabHeight - 2*bbh - 2*bh, pw/3, bh]); %, 'HorizontalAlignment', 'right');
            obj.gui.keyEnabled = uicontrol('Parent', obj.gui.tabInputs, 'Style', 'check', 'String', 'Keyboard', 'Position', [pw/3,   tabHeight - 2*bbh - 2*bh, pw/3, bh], 'Value', 1);
            obj.gui.joyEnabled = uicontrol('Parent', obj.gui.tabInputs, 'Style', 'check', 'String', 'Joystick', 'Position', [2*pw/3, tabHeight - 2*bbh - 2*bh, pw/3, bh], 'Value', obj.config.joyEnabled, 'Callback', @obj.joyEnableFunction); %, 'Enable', 'off');
            
            uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', 'Keyboard Step', 'Position', [pw/3,   tabHeight - 2*bbh - 4*bh, pw/3, bh]);
            uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', 'Joystick Step', 'Position', [2*pw/3, tabHeight - 2*bbh - 4*bh, pw/3, bh]);
            
            y = tabHeight - 2*bbh - 5*bh;
            
            for axis_ = obj.config.axesList
                uicontrol('Parent', obj.gui.tabInputs, 'Style', 'text', 'String', [axis_{1}.config.name ' (' axis_{1}.config.kind.extUnits '): '], 'Position', [0,         y, pw/3, bh], 'HorizontalAlignment', 'right');
                uicontrol('Parent', obj.gui.tabInputs, 'Style', 'edit', 'String', axis_{1}.config.keyStep, 'Position', [pw/3,    y, pw/3, bh], 'Callback', {@setAxisKeyStep_Callback, axis_{1}});
                uicontrol('Parent', obj.gui.tabInputs, 'Style', 'edit', 'String', axis_{1}.config.joyStep, 'Position', [2*pw/3,  y, pw/3, bh], 'Callback', {@setAxisJoyStep_Callback, axis_{1}});
                
                y = y - bh;
            end
            
            obj.gui.joy.throttle = 0;
            obj.gui.joyState = -1;
            obj.gui.axisState = [0 0 0];
            
            f.Visible = 'on';
            pause(.1);
            obj.joyEnableFunction(0,0);
        end
        
        function openListener(obj)
            fl = mcAxisListener(obj.config.axesList);
            fl.Position(2) = 670;
        end
        function openWaypoints(obj)
            obj.wp = mcWaypoints(mcWaypoints.customConfig(obj.config.axesGroups{1}{2}, obj.config.axesGroups{1}{3}, obj.config.axesGroups{1}{4}));
            obj.wp.f.Position(2) = 400;
        end
        
        function setUserInputMode(obj, ~, ~, mode)
            obj.mode = mode;
            obj.refreshUserInputMode();
        end
        function refreshUserInputMode(obj)
            ii = 1;
            for panel = obj.gui.gotoPanels
                if obj.mode == ii
                    panel{1}.HighlightColor = 'red';
                else
                    panel{1}.HighlightColor = 'white';
                end
                
                ii = ii + 1;
            end
            ii = 1;
            for panel = obj.gui.inputPanels
                if obj.mode == ii
                    panel{1}.HighlightColor = 'red';
                else
                    panel{1}.HighlightColor = 'white';
                end
                
                ii = ii + 1;
            end
        end
        
        function joyEnableFunction(obj, ~, ~)
            if isvalid(obj)
%                 check = obj.gui.joyEnabled.Value
                if obj.gui.joyEnabled.Value
                    mcJoystickDriver(@obj.joyActionFunction);
                else
                    
                end
            else
                % Do something to stop the joystick?
            end
        end
        function shouldContinue = joyActionFunction(obj, ~, event)  % Interprets messages sent by the joystick, returns whether the joystick shouldContinue or not.
            shouldContinue = 1;
            
            if isvalid(obj)                     % If the UserInput window/class hasn't closed...
                if obj.gui.joyEnabled.Value     % If the checkbox is still checked...
                    switch event.type
                        case 0      % Debug
                            obj.gui.joyState = event.axis;          % -1:off, 0:can't find id, 1:running
                        case 1                                  % Numbered buttons
                            if event.value == 1                 % If a button was pressed,
                                num = obj.config.numGroups+1;

                                switch event.axis               % Figure out what button was pressed (by number) and perform the appropriate action.
                                    case 1
                                        if ~isempty(obj.wp) && isvalid(obj.wp)
                                            obj.wp.dropAtAxes_Callback(0, 0);
                                        else
                                            disp('No waypoints connected; not sure what to do when pressing the joystick trigger...');
                                        end
                                    case 2
                                        'Side'
                                    case 3
                                        '3'
                                    case 4
                                        obj.userAction(3, -1, 1);
                                    case 5
                                        '5'
                                    case 6
                                        obj.userAction(3, 1, 1);
                                    case 7
                                        num = 1;
                                    case 8
                                        num = 4;
                                    case 9
                                        num = 2;
                                    case 10
                                        num = 5;
                                    case 11
                                        num = 3;
                                    case 12
                                        num = 6;
                                end

                                if num <= obj.config.numGroups
                                    obj.setUserInputMode(0, 0, num);
                                end
                            end
                        case 2      % POV
                            if event.value < 360
                                x = sind(event.value);
                                y = cosd(event.value);
                                
                                obj.userAction(1, x, 1);
                                obj.userAction(2, y, 1);
                            end
                        case 3      % Axis
                            obj.gui.axisState(event.axis) = event.value;
                            
                            if event.axis ~= 3 || sum(obj.gui.axisState(1:2).*obj.gui.axisState(1:2)) < .25     % If XY is displaced by more than .25, block Z.
                                userAction(obj, event.axis, event.value*event.value*event.value, 0)     % Note the cube...
                            end
                        case 4      % Throttle
                            obj.gui.joy.throttle = event.value;
                    end
                else
                    shouldContinue = 0;     % Returns 0 (stop to the joystick).
                end
            else
                shouldContinue = 0;         % Returns 0 (stop to the joystick).
            end
        end
        function keyPressFunction(obj, ~, event)                    % Interprets messages sent by the keyboard.
%             event
            
            if isvalid(obj)                     % If the UserInput window/class hasn't closed...
                if obj.gui.keyEnabled.Value     % If the checkbox is still checked...
                    % First, decide whether it is appropriate to accept keyboard input in this context.
                    focus = gco;

                    if isprop(focus, 'Style')
                        % Inappropriate contexts include, e.g. edit boxes, etc.
                        proceed = (~strcmpi(focus.Style, 'edit') && ~strcmpi(focus.Style, 'choose')) || ~strcmpi(focus.Enable, 'on');    % Don't continue if we are currently changing the value of a edit uicontrol...
                    else
                        proceed = true;
                    end

                    if proceed                                  % If it is appropriate, then proceed.
                        multiplier = 1;
                        if ismember(event.Modifier, 'shift')    % The shift key speeds all movement by a factor of 10.
                            multiplier = multiplier*10;
                        end
                        if ismember(event.Modifier, 'alt')      % The alt key slows all movement by a factor of 10.
                            multiplier = multiplier/10;
                        end

                        switch event.Key                        % Now figure out which way we should move...
                            case {'rightarrow', 'd'}
                                obj.userAction(1,  multiplier, 1);
                            case {'leftarrow', 'a'}
                                obj.userAction(1, -multiplier, 1);
                            case {'uparrow', 'w'}
                                obj.userAction(2,  multiplier, 1);
                            case {'downarrow', 's'}
                                obj.userAction(2, -multiplier, 1);
                            case {'equal', 'add', 'e', 'pageup'}
                                obj.userAction(3,  multiplier, 1);
                            case {'hyphen', 'subtract', 'q', 'pagedown'}
                                obj.userAction(3, -multiplier, 1);
                            case {'1', '2', '3', '4', '5', '6', '7', '8', '9'}  % The number keys switch the selected axis group.
                                num = str2double(event.Key);

                                if num <= obj.config.numGroups
                                    obj.mode = num;
                                else
                                    obj.mode = 0;
                                end

                                obj.refreshUserInputMode();
                            case {'backquote', '0'}     % Backquote or zero deselects all axis groups.
                                obj.mode = 0;
                                obj.refreshUserInputMode();
                        end
                    end
                end
            else                                % If the UserInput has closed, then make sure that this function is no longer referenced (cut ties).
                mcInstrumentHandler.setGlobalWindowKeyPressFcn('');
            end
        end
        
        function userAction(obj, axis_, value, isKey)   % Function to simplify all inputs (keyboard or joystick).
            % 1 < = axis_ <= 3 (one of the three possible axes).
            % value is multiplier (negative implies other direction).
            % isKey implies use keyboard speeds.
            % isKey implies use joystick speeds.
            
            if axis_ < 1 || axis_ > 3
                warning(['mcUserInput.userAction(): axis_ must be 1, 2, or 3, not ' num2str(axis_)]);
            else
                if value ~= 0
                    if obj.mode > 0 && obj.mode <= obj.config.numGroups
                        a = obj.config.axesGroups{obj.mode}{axis_+1};

                        if strcmpi(a.config.kind.kind, 'nidaqdigital')
                            dVal = sign(value);
                        else
                            if isKey
                                dVal = value*a.config.keyStep;
                            else
                                dVal = value*a.config.joyStep*obj.gui.joy.throttle;
                            end
                        end

                        if dVal ~= 0                                                        % If there was a change...
                            val = a.config.kind.int2extConv(a.x) + dVal;                    % ...calculate the result.

                            if abs(val - a.config.kind.int2extConv(a.xt)) > abs(5*dVal)     % If the axis is lagging too far behind...
                                obj.flashKey(2*axis_ + (sign(value)-1)/2, [0 0.9400 0], false);    % ...then flash green
                            else
                                if iscell(a.config.kind.extRange)
                                    switch val
                                        case a.config.kind.extRange
                                            % nothing
                                        otherwise
                                            l = [a.config.kind.extRange{:}] - val;
                                            val = a.config.kind.extRange{find(l.*l == min(l.*l), 1)};     % Change?
                                    end
                                else
                                    if val >  max(a.config.kind.extRange)                       % Make sure the axis doesn't go out of bounds
                                        val = max(a.config.kind.extRange);
                                    end
                                    if val <  min(a.config.kind.extRange)
                                        val = min(a.config.kind.extRange);
                                    end
                                end

                                if abs(val) < 1e-14
                                    val = 0;                                                % Account for arithmatic error.
                                end

                                a.goto(val);                                                % Finally, go to the new position.

                                obj.flashKey(2*axis_ + (sign(value)-1)/2, [0.9400 0 0], isKey);    % ...then flash red
                            end
                        else                                                                % If there wasn't a change...
                            obj.flashKey(2*axis_ + (sign(value)-1)/2, [0.9400 0.9400 0], isKey);   % ...then flash yellow
                        end
                    else
                        obj.flashKey(2*axis_ + (sign(value)-1)/2, [0 0 0.9400], isKey);            % ...then flash blue
                    end
                end
            end
        end
        function flashKey(obj, key, color, isKey)       % Flash a color on the UI arrow keys.
            if isKey
                obj.gui.keylist(key).BackgroundColor = color;
                pause(.032);
                obj.gui.keylist(key).BackgroundColor = [0.9400    0.9400    0.9400];
            end
        end
        function userAction_Callback(obj, src, ~, axis_, direction)     % Function the UI arrow keys call to move the axes.
            src.Enable = 'off';
%             drawnow;
            src.Enable = 'on';  % This is to remove focus on whatever object may be focused.
            obj.userAction(axis_, direction, 1);
        end

        function tf = makeAxisControls(obj, axis_, parent, y, ii)
%             disp('Making axis');
            fw = 300;               % Figure width
            fh = 500;               % Figure height

            pp = 5;                 % Panel padding
            pw = fw-40;             % Panel width
            ph = 200;               % Panel height

            bh = 20;                % Button Height

            text = uicontrol(   'Parent', parent,...
                                'Style', 'text',...
                                'String', [axis_.config.name ' (' axis_.config.kind.extUnits '): '],...
                                'Position', [pp, y, pw/3, bh],...
                                'HorizontalAlignment', 'right',...
                                'tooltipString', axis_.name(),...
                                'HitTest', 'off');
%                                 'ButtonDownFcn', {@obj.setUserInputMode, ii});
%             jButton= findjobj(text);
%             set(jButton,'Enabled',false);
%             set(jButton,'ToolTipText', axis_.name());

            if      iscell(axis_.config.kind.intRange) && length(axis_.config.kind.intRange) == 2 &&...
                    any(xor([~axis_.config.kind.intRange{1} ~axis_.config.kind.intRange{2}], [~axis_.config.kind.intRange{2} ~axis_.config.kind.intRange{1}]))    % If we should make a toggle switch instead of an edit box...
                edit = uicontrol(   'Parent', parent,...
                                    'Style', 'checkbox',...
                                    'Value',  ~~axis_.getX(),...
                                    'Position', [pp+pw/3+pw/8 - bh/2, y, bh, bh],...
                                    'Callback', {@toggle_Callback, @axis_.goto, axis_.config.kind.extRange},...
                                    'tooltipString', axis_.nameRange());
                get = uicontrol(    'Parent', parent,...
                                    'Style', 'push',...
                                    'String', 'Get',...
                                    'Position', [2*pp+pw/3 + pw/4, y, pw/3, bh],...
                                    'Callback', {@setToggleWithValue_Callback, @()(~~axis_.getX()), edit});
%                 goto = uicontrol(   'Parent', parent,...
%                                     'Style', 'push',...
%                                     'String', 'Goto',...
%                                     'Position', [2*pp+3*pw/4, y, pw/6, bh],...
%                                     'Callback', {@evalFuncWithEditValue_Callback, @axis_.goto, edit});
            else
                edit = uicontrol(   'Parent', parent,...
                                    'Style', 'edit',...
                                    'String', axis_.getX(),...
                                    'Value',  axis_.getX(),...
                                    'Position', [pp+pw/3, y, pw/4, bh],...
                                    'Callback', {@limit_Callback, axis_.config.kind.extRange},...
                                    'tooltipString', axis_.nameRange());
                get = uicontrol(    'Parent', parent,...
                                    'Style', 'push',...
                                    'String', 'Get',...
                                    'Position', [2*pp+pw/3 + pw/4, y, pw/6, bh],...
                                    'Callback', {@setEditWithValue_Callback, @axis_.getX, edit});
                goto = uicontrol(   'Parent', parent,...
                                    'Style', 'push',...
                                    'String', 'Goto',...
                                    'Position', [2*pp+3*pw/4, y, pw/6, bh],...
                                    'Callback', {@evalFuncWithEditValue_Callback, @axis_.goto, edit});
            end

            tf = 1;

        %     l = event.proplistener(axis_, 'inUse', 'PostSet', {@makeUIControlsInactive, [text, edit, get, goto]});
        end
        
        function closeRequestFcn(obj,~,~)
            obj.gui.joyEnabled.Enable = 'off';      % Stop the joystick
            obj.gui.joyEnabled.Value = 0;
            
            % If this mcUserInput's keyPressFunction is used as the globalWindowKeyPressFcn...
            if mcInstrumentHandler.isOpen() && isequal(@obj.keyPressFunction, mcInstrumentHandler.globalWindowKeyPressFcn())
                mcInstrumentHandler.setGlobalWindowKeyPressFcn([]);     % Then remove this from every figure.
                    
                % And ask whether the axis info (joystep, etc) should be saved.
            end
            
            pause(1);               % Give the joystick a chance to keep up...
            
            delete(obj.gui.f);      % Then delete everything.
            delete(obj);
        end
    end
end

function setAxisKeyStep_Callback(src, ~, axis_)
    val = str2double(src.String);

    if isnan(val)
        val = axis_.config.keyStep;
    end

    src.String = val;
    axis_.config.keyStep = val;
    
    % Save axis config?
end
function setAxisJoyStep_Callback(src, ~, axis_)
    val = str2double(src.String);

    if isnan(val)
        val = axis_.config.joyStep;
    end

    src.String = val;
    axis_.config.joyStep = val;
    
    % Save axis config?
end

function limit_Callback(src, ~, range)
    val = str2double(src.String);

    if isnan(val)                   % If it's NaN (if str2double fails), check if it's an equation (eval is ~20 times slower so we only want to use it if it is neccessary)
        try
            val = eval(src.String); % Try to interpret string with eval...
        catch
            val = src.Value;        % If this fails, set to the previous value (stored in Value).
        end
    end

    if isnan(val)                   % If it's still NaN, set to the previous value (stored in Value).
        val = src.Value;
    end
    
    % Now truncate value to the range...
    if iscell(range)
        switch val
            case range
                % nothing
            otherwise
                l = [range{:}] - val;
                val = range{find(l.*l == min(l.*l), 1)};     % Change?
        end
    else
        if val > max(range)
            val = max(range);
        end
        if val < min(range)
            val = min(range);
        end
    end
    
    src.String = val;
    src.Value = val;
end

function toggle_Callback(src, ~, func, range)
    src.Enable = 'off';
    drawnow;
    src.Enable = 'on';
    func(range{src.Value + 1});
end

function setEditWithValue_Callback(src, ~, val, edit)
    src.Enable = 'off';
    drawnow;
    src.Enable = 'on';
    edit.String = val();
end

function setToggleWithValue_Callback(src, ~, val, edit)
    src.Enable = 'off';
    drawnow;
    src.Enable = 'on';
    edit.Value = val();
end

% function makeUIControlsInactive(src, event, controls)
%     set(controls, 'Active'
% end

function evalFuncWithEditValue_Callback(src, ~, func, edit)
    src.Enable = 'off';
    drawnow;
    src.Enable = 'on';
    func(str2double(edit.String));
end

            
function sendEditsToTopOfUIStack(obj)   % Not working perfectly.
%     obj.Children
%     length(obj.Children)
%     iscell(obj.Children)
    for ii = 1:length(obj.Children)
        child = obj.Children(ii);
        
        if isfield(child, 'Style') || isprop(child, 'Style')
            if strcmpi(child.Style, 'edit')
                uistack(child, 'top');
            end
        end
        
%         isfield(child, 'Children')
%         isprop(child, 'Children')
        
        if isfield(child, 'Children') || isprop(child, 'Children')
%             Children = child.Children
            sendEditsToTopOfUIStack(child);       % Recurse.
        end
    end
end

