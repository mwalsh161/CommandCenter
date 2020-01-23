classdef SweepController < handle
    % SWEEPCONTROLLER is a UI for controlling (starting/pausing/resetting) a sweep apart from other UI
    % elements (e.g. Base.ScanViewer).

    properties (SetAccess=private)
        panel;
        gui;
        child;
    end
    properties (Dependent)
        running
    end
    
    methods
		function obj = SweepController(varargin)
            if isempty(varargin)
                f = figure;
                f.Position(3) = 300;
                obj.panel = uipanel();
            else
                obj.panel = varargin;
            end
            
            obj.panel.Units = 'characters';
            h = 2.5;
            w = obj.panel.Position(3)-4;
            obj.panel.Position(4) = h;
            
            bh = 1.2;
            p = 2;
            
            obj.gui.toggle = uicontrol( 'Style', 'togglebutton',...
                                        'Interruptible', 'off',...
                                        'Units', 'characters',...
                                        'Position', [p,(h-bh)/2,.3*w,bh],...
                                        'Callback', @obj.toggle_Callback); p = p + .3*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'Index: ',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'right',...
                                            'Position', [p,(h-bh)/2,.15*w,bh]); p = p + .15*w;
            obj.gui.index = uicontrol(      'Style', 'edit',...
                                            'String', 1,...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,(h-bh)/2,.15*w,bh],...
                                            'Callback', @obj.index_Callback); p = p + .15*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'of',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'center',...
                                            'Position', [p,(h-bh)/2,.05*w,bh]); p = p + .05*w;
            obj.gui.indexTotal = uicontrol( 'Style', 'edit',...
                                            'String', 100,...
                                            'UserData', 100,...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,(h-bh)/2,.15*w,bh]); p = p + .175*w;
                                        
            obj.gui.tick =   uicontrol( 'Style', 'pushbutton',...
                                        'Units', 'characters',...
                                        'String', 'Tick',...
                                        'Position', [p,(h-bh)/2,.175*w,bh],...
                                        'Callback', @obj.toggle_Callback);
            obj.setToggleString();
        end
        
        function index_Callback(obj, ~, ~)
            try
                obj.gui.index.String = max(1, min(obj.gui.indexTotal.UserData, round(str2double(obj.gui.index.String))));
            catch
                obj.gui.index.String = 1;
            end
        end
        
        function toggle_Callback(obj, ~, ~)
            obj.setToggleString();
        end
        function toggle(obj)
            obj.running = ~obj.running;
        end
        function setToggleString(obj)
            if obj.running
                obj.gui.toggle.String =     'Sweeping...';
                obj.gui.toggle.Tooltip =    'Click to stop sweeping.';
                obj.gui.index.Enable =      'inactive';
                obj.gui.tick.Enable =       'off';
            else
                obj.gui.toggle.String =     'Sweep';
                obj.gui.toggle.Tooltip =    'Click to start sweeping.';
                obj.gui.index.Enable =      'on';
                obj.gui.tick.Enable =       'on';
            end
        end
        
        function val = get.running(obj)
            val = obj.gui.toggle.Value;
        end
        function set.running(obj, val)
            obj.gui.toggle.Value = val;
            obj.setToggleString()
        end
    end
end
