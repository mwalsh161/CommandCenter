classdef SweepController < handle
    % SWEEPCONTROLLER is a UI for controlling (starting/pausing/resetting) a sweep apart from other UI
    % elements (e.g. Base.ScanViewer).

    properties (SetAccess={?Base.SweepController, ?Base.Sweep})
        panel;
        gui;
        sweep;
        lasttick = 0;
    end
    properties (Dependent)
        running
    end
    
    methods
		function obj = SweepController(sweep, varargin)
            obj.sweep = sweep;
            
            if isempty(varargin)
                f = figure;
                f.Position(3) = 300;
                obj.panel = uipanel();
            else
                obj.panel = varargin{1};
            end
            
            obj.panel.Units = 'characters';
            h = obj.panel.Position(4);
            w = obj.panel.Position(3)-4;
%             obj.panel.Position(4) = h;
            
            bh = 1.4;
            p = 2;
            
            obj.gui.toggle = uicontrol( 'Style', 'togglebutton',...
                                        'Interruptible', 'off',...
                                        'Units', 'characters',...
                                        'Position', [p,h-3*bh/2,.3*w,bh],...
                                        'Callback', @obj.toggle_Callback); p = p + .3*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'Index: ',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'right',...
                                            'Position', [p,h-3*bh/2-.2,.15*w,bh]); p = p + .15*w;
            obj.gui.index = uicontrol(      'Style', 'edit',...
                                            'String', 1,...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,h-3*bh/2,.15*w,bh],...
                                            'Callback', @obj.index_Callback); p = p + .15*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'of',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'center',...
                                            'Position', [p,h-3*bh/2-.2,.05*w,bh]); p = p + .05*w;
            obj.gui.indexTotal = uicontrol( 'Style', 'edit',...
                                            'String', 100,...
                                            'UserData', 100,...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,h-3*bh/2,.15*w,bh]); p = p + .175*w;
                                        
            obj.gui.tick =   uicontrol( 'Style', 'pushbutton',...
                                        'Units', 'characters',...
                                        'String', 'Tick',...
                                        'Position', [p,h-3*bh/2,.175*w,bh],...
                                        'Callback', @obj.tick_Callback);
            obj.setToggleString();
        end
        
        function index_Callback(obj, ~, ~)
            try
                ii = max(1, min(obj.gui.indexTotal.UserData, round(str2double(obj.gui.index.String))));
                obj.gui.index.String = ii;
                if ~isempty(obj.sweep) && isvalid(obj.sweep)
                    obj.sweep.index = ii;
                end
            catch
                obj.gui.index.String = 1;
            end
        end
        
        function tick_Callback(obj, ~, ~)
            thistick = str2double(obj.gui.index.String);
            if obj.lasttick ~= thistick
                obj.lasttick = thistick;
                obj.sweep.tick();
            end
        end
        
        function toggle_Callback(obj, ~, ~)
            if strcmp(obj.gui.index.String, 'Done') || strcmp(obj.gui.index.String, obj.gui.indexTotal.String)
                obj.toggle;
            end
            obj.setToggleString();
        end
        function toggle(obj)
            obj.running = ~obj.running;
        end
        function setToggleString(obj)
            if obj.running
                obj.gui.toggle.String =         'Sweeping...';
                obj.gui.toggle.Interruptible =  'off';
                obj.gui.toggle.Tooltip =        'Click to stop sweeping.';
                obj.gui.index.Enable =          'inactive';
                obj.gui.tick.Enable =           'off';
                
                obj.sweep.snap();
            else
                obj.gui.toggle.String =         'Sweep';
                obj.gui.toggle.Interruptible =  'on';
                obj.gui.toggle.Tooltip =        'Click to start sweeping.';
                obj.gui.index.Enable =          'on';
                obj.gui.tick.Enable =           'on';
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
