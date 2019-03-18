classdef Lithography < Modules.Experiment
    %LITHOGRAPHY Summary of this class goes here
    %   Writes a file that has a variable called Sequence (Nx4 array)
    %   [x y z laser]
    %       x,y,z are voltages (float)
    %       laser is binary state (bool)
    
    properties
        dwell = 1;          % ms per point
        file='';            % File to use on the 'path'
        laserLine;          % PulseBlaster line for laser
        x;                  % Line name for x galvo (nidaq)
        y;                  % Line name for y galvo (nidaq)
        z;                  % Line name for z piezo (nidaq)
        trigger;            % Line name for trigger to pb (nidaq)
        prefs = {'dwell','laserLine','file','x','y','z','trigger','file'};
    end
    properties(Access=private)
        ni                  % NIDAQ
        pb                  % PulseBlaster
        task = struct('PulseTrain',[],'Galvos',[],'Trigger',[]);   % NIDAQ tasks when running
        abort_requested = false;
        status_handle       % Handle to status when experiment started (for abort)
    end
    
    methods(Access=private)
        function obj = Lithography()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            obj.pb = Drivers.PulseBlaster.ESRpro.instance(0);
            addlistener(obj.pb,'ObjectBeingDestroyed',@(~,~)obj.delete);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Lithography();
            end
            obj = Object;
        end
    end
    methods
        function abort(obj)
            obj.abort_requested = true;
            set(obj.status_handle,'string','Aborting...')
        end
        
        run(obj,status,managers,ax)
        init_nidaq(obj,voltages)
        
        function updateTime(~,status,timeLeft)
            hrs = floor(timeLeft/(60*60));
            timeLeft = timeLeft-hrs*60*60;
            min = floor(timeLeft/60);
            sec = round(timeLeft-min*60);
            set(status,'string',sprintf('Approximate Time Left: %i:%i:%i',hrs,min,sec));
        end
        
        function init_pulseblaster(obj,laserStates)
            obj.pb.stop;
            obj.pb.start_programming;
            obj.compile(laserStates);
            obj.pb.stop_programming;
        end
        
        function compile(obj,writeSequence)
            % writeSequence is logical array of 1xN
            try
                writeSequence = logical(writeSequence);
            catch
                error('writeSequence must be convertable to logical array.')
            end
            length = 100;  %ns
            wait_length = round(obj.dwell*1e6*2/3);  % Get dwell to ns
            lines = zeros(1,21);
            flags = bitor(obj.pb.ON,bi2de(lines));
            obj.pb.instruction(flags, 'CONTINUE',0, length);
            obj.pb.instruction(flags,'WAIT',0, length);
            while numel(writeSequence)~=0
                [~, ia] =unique(writeSequence,'stable');
                if numel(ia) > 1
                    n = ia(2)-1;
                else
                    n = numel(writeSequence);
                end
                lines = zeros(1,21);
                lines(obj.laserLine) = writeSequence(1);
                flags = bitor(obj.pb.ON,bi2de(lines));
                writeSequence(1:n)=[];
                if n > 1
                    inst_addr = obj.pb.instruction(flags,'LOOP', n, wait_length);
                    obj.pb.instruction(flags,'WAIT', 0, length);
                    obj.pb.instruction(flags, 'END_LOOP',inst_addr, length);
                else
                    obj.pb.instruction(flags, 'CONTINUE',0, wait_length);
                    obj.pb.instruction(flags, 'WAIT',0, length);
                end
            end
            % Turn off and stop program
            obj.pb.instruction(0, 'CONTINUE',0, length);
            obj.pb.instruction(0, 'STOP',0, length);
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % No data to return, 
            dat.ExpName = mfilename;
            dat.dwell = obj.dwell;
            dat.FileUsed = obj.file;
            dat.time = datetime('now');
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
            spacing = 2.25;
            num_lines = 1;
            line = 1;
            uicontrol(panelH,'style','PushButton','String','Configure Write',...
                'units','characters','position',[1 spacing*(num_lines-line) 22 1.75],...
                'callback',@obj.configWrite);
            line = 1;
            if isempty(obj.file)
                tip = 'No File';
            else
                tip = obj.file;
            end
            uicontrol(panelH,'style','PushButton','String','Write File','tooltipstring',tip,...
                'units','characters','position',[25 spacing*(num_lines-line) 22 1.75],...
                'callback',@obj.chooseFile);
        end
        function configWrite(obj,~,~)
            % dwell
            % PulseBlaster: laserLine
            % NIDAQ: x, y, z, trigger
            prompts = {'Dwell time (ms):','Laser line from PulseBlaster',...
                'x line from NIDAQ','y line from NIDAQ','z line from NIDAQ',...
                'Trigger from NIDAQ (to PulseBlaster)'};
            default = {obj.dwell,obj.laserLine,obj.x,obj.y,obj.z,obj.trigger};
            default = cellfun(@num2str,default,'uniformoutput',0);
            answer = inputdlg(prompts,'Configure Lithography Write',1,default);
            if ~isempty(answer)
                if str2double(answer{1})*1e-3 > 8.5
                    errordlg('Dwell time greater than 8.5 seconds is not allowed. PulseBlaster will not wait this long.')
                else
                    obj.dwell = str2double(answer{1});
                end
                obj.x = answer{3};
                obj.y = answer{4};
                obj.z = answer{5};
                obj.trigger = answer{6};
                if isnan(str2double(answer{2}))
                    errordlg('Laser Line must be an integer.');
                else
                    obj.laserLine = str2double(answer{2});
                end
            end
        end
        function chooseFile(obj,hObj,~)
            [filename,pathname] = uigetfile({'*.mat','*.*'},'Write File',obj.file);
            if filename
                obj.file = fullfile(pathname,filename);
                set(hObj,'tooltipstring',obj.file);
            end
        end
    end
    
end

