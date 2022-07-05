classdef Galvos < Modules.Stage
    %GALVOS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        prefs = {'use_z'}
    end
    properties(SetObservable, GetObservable)
        use_z = Prefs.Boolean(true);
    end
    properties(SetAccess=private)
        position
    end
    properties(SetAccess=private,SetObservable)
        Moving = false;
    end
    properties(SetAccess=immutable,Hidden)
        galvoDriver
    end
    properties(Constant)
        xRange = [-3 3];
        yRange = [-3 3];
        zRange = [-10 10];
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.Galvos();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = Galvos()
            obj.loadPrefs;
            if obj.use_z
                try
                    obj.galvoDriver = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','GalvoScanSync');
                catch err
                    if ~isempty(strfind(err.message,'No line with name "Z".'))
                        answer = questdlg(sprintf('Continue without Z?\nYou can change later by unchecking in module settings.'),'NIDAQ','yes','no','yes');
                        if strcmp(answer,'yes')
                            obj.galvoDriver = Drivers.NIDAQ.stage.instance('X','Y','','APD1','GalvoScanSync');
                            obj.use_z = false;
                        else
                            rethrow(err)
                        end
                    end
                end
            else
                obj.galvoDriver = Drivers.NIDAQ.stage.instance('X','Y','','APD1','GalvoScanSync');
            end
            addlistener(obj.galvoDriver,'moving','PostSet',@obj.update_Moving);
        end
    end
    methods
        function update_Moving(obj,varargin)
            if isvalid(obj)  % I tried for a good day trying to figure this shit out. Shouldn't need this if statement!
                obj.Moving = obj.galvoDriver.moving;
            end
        end
        function val = get.position(obj)
            val = obj.galvoDriver.voltage;
        end
        
        function move(obj,x,y,z)
            try
                obj.galvoDriver.SetCursor(x,y,z)
            catch err  % Ignore already moving error
                if ~strcmp(err.message,'Galvos are currently moving!')
                    rethrow(err)
                end
            end
        end
        function home(obj)
            obj.move(0,0,0)
        end
        function abort(obj,immediate)
            % Action is basically instant!
        end
        
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 4;
            line = 1;
            uicontrol(panelH,'style','checkbox','string','Use Z','horizontalalignment','right',...
                'units','characters','position',[2 spacing*(num_lines-line) 18 1.25],...
                'value',obj.use_z,'callback',@obj.use_zCallback);
        end
        function use_zCallback(obj,hObj,~)
            if ~obj.use_z && get(hObj,'Value') % Going from not using to using
                warndlg('Might need to reload this module after enabling Z.')
            end
            obj.use_z = get(hObj,'Value');
        end
    end
    
end

