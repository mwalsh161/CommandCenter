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
            w = obj.panel.Position(3)-2;
%             obj.panel.Position(4) = h;
            
            bh = 1.4;
            p = 1;
            
            obj.gui.toggle = uicontrol( 'Style', 'togglebutton',...
                                        'Units', 'characters',...
                                        'Position', [p,h-3*bh/2,.28*w,bh],...
                                        'Callback', @obj.toggle_Callback); p = p + .28*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'Index: ',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'right',...
                                            'Position', [p,h-3*bh/2-.2,.125*w,bh]); p = p + .125*w;
            obj.gui.index = uicontrol(      'Style', 'edit',...
                                            'String', 1,...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,h-3*bh/2,.125*w,bh],...
                                            'Callback', @obj.index_Callback); p = p + .125*w;
            
            
            uicontrol(                      'Style', 'text',...
                                            'String', 'of',...
                                            'Units', 'characters',...
                                            'HorizontalAlignment', 'center',...
                                            'Position', [p,h-3*bh/2-.2,.05*w,bh]); p = p + .05*w;
            obj.gui.indexTotal = uicontrol( 'Style', 'edit',...
                                            'String', prod(obj.sweep.size),...
                                            'UserData', prod(obj.sweep.size),...
                                            'Enable', 'inactive',...
                                            'Units', 'characters',...
                                            'Position', [p,h-3*bh/2,.125*w,bh]); p = p + .135*w;
                                        
            obj.gui.tick =   uicontrol( 'Style', 'pushbutton',...
                                        'Units', 'characters',...
                                        'String', 'Tick',...
                                        'Position', [p,h-3*bh/2,.14*w,bh],...
                                        'Callback', @obj.tick_Callback); p = p + .15*w;
                                    
            obj.gui.reset =  uicontrol( 'Style', 'pushbutton',...
                                        'Units', 'characters',...
                                        'String', 'Reset',...
                                        'Position', [p,h-3*bh/2,.14*w,bh],...
                                        'Callback', @obj.reset_Callback);
            obj.setToggleString();
            obj.setIndex;
        end
        
        function index_Callback(obj, ~, ~)
            try
                if strcmp(obj.gui.index.String, 'Done')
                    return;
                end
                
                ii = max(1, min(obj.gui.indexTotal.UserData, round(str2double(obj.gui.index.String))));
                obj.gui.index.String = ii;
                if ~isempty(obj.sweep) && isvalid(obj.sweep)
%                     obj.sweep.index = ii;
                    obj.sweep.gotoIndex(ii);
                end
            catch err
                obj.setIndex;
                rethrow(err);
            end
        end
        
        function setIndex(obj)
            if obj.sweep.index > obj.gui.indexTotal.UserData
                obj.gui.index.String = 'Done';
            else
                obj.gui.index.String = obj.sweep.index;
            end
        end
        
        function tick_Callback(obj, ~, ~)
            thistick = str2double(obj.gui.index.String);
            if obj.lasttick ~= thistick     % Prevents clicking tick very fast and ticking twice on the same point.
                obj.lasttick = thistick;
                obj.sweep.tick();
            end
        end
        function reset_Callback(obj, ~, ~)
            obj.sweep.reset();
        end
        
        function toggle_Callback(obj, ~, ~)
            obj.setToggleString();
            
            if (strcmp(obj.gui.index.String, 'Done') || strcmp(obj.gui.index.String, obj.gui.indexTotal.String))
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
%                 obj.gui.toggle.Interruptible =  'off';
                obj.gui.toggle.TooltipString =  'Click to stop sweeping.';
                obj.gui.index.Enable =          'inactive';
                obj.gui.tick.Enable =           'off';
                obj.gui.reset.Enable =          'off';
                
                obj.sweep.measure();
                
                obj.running = false;
            else
                obj.gui.toggle.String =         'Sweep';
%                 obj.gui.toggle.Interruptible =  'on';
                obj.gui.toggle.TooltipString =  'Click to start sweeping.';
                obj.gui.index.Enable =          'on';
                obj.gui.tick.Enable =           'on';
                obj.gui.reset.Enable =          'on';
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
