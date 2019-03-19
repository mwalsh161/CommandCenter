classdef AutoSlowScan < Modules.Experiment
    
    properties
        scan
        ip = 'Deprecated Use';
        wavemeter_channel = 1;
        specip = 'Deprecated Use';
        chipSize = [3000 3000];
        mirror1 = 'FlipMirror1';
        mirror2 = 'FlipMirror2';
        newImage = false;
        greentime = 2;
        redtime = 10;
        prefs = {'ip','specip','chipSize','mirror1','mirror2','NVsize','SpecPath','newImage','greentime','redtime','wavemeter_channel'};
        PointThresh = 10; %number of points we want on the resonance in order to be satisfied
        SNRThresh = 5; %SNR (peak amp/data STD) in order to be satisfied
        path %temporary
        NVsize = 0.2; %expected NV spot size in microns (diameter)
        SpecPath = '';
        maxAverages = 1e6;
        ScanResolution = 20e-6; %resolution for final slow scans in THz
        abort_request = false;  % Request flag for abort
        pause_request = false;
        spec2wave = struct('cal_func',{},'datetime',{});
    end
    properties(Constant)
        c = 299792; %speed of light in nm/s for converting wavelength to frequency
        cal_timeout = 24*7; %hours until start getting warning about callibration between spectrometer and wavemeter
    end
    properties (SetAccess=private)
        mov = struct('dt',[],'frame',[]);
        rl; %red light is private
        gl; %green light is private
        nidaq;
        pb;
        galvos;
        WinSpec;
        wavemeter;
        listeners;
        path_button;
    end
    
    methods(Access=private)
        function obj = AutoSlowScan()
            obj.loadPrefs;
            obj.rl = Sources.VelocityLaser.instance;
            obj.gl = Sources.Laser532_PB.instance;
            obj.galvos = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','GalvoScanSync');
            obj.nidaq = Drivers.NIDAQ.dev.instance('Dev1');
            obj.WinSpec = Drivers.WinSpec.instance(obj.specip);
            obj.listeners = addlistener(obj.WinSpec,'path','PostSet',@obj.SpecPathSet);
            obj.wavemeter = Drivers.Wavemeter.instance(obj.ip,obj.wavemeter_channel);
            obj.pb = Drivers.PulseBlaster.Remote.instance(obj.ip);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.AutoSlowScan();
            end
            obj = Object;
        end
        
        varargout = BuildPulseSequence(greentime,redtime,averages);
        varargout = view(varargin);
    end

    methods
        function delete(obj)
            delete(obj.listeners)
        end
        run(obj,statusH,managers,ax)
        function abort(obj)
            if obj.WinSpec.running
                obj.WinSpec.abort();
            end
            obj.abort_request = true;
            obj.logger.log('Abort requested');
        end
        function pause(obj,~,~)
            obj.pause_request = true;
            obj.logger.log('Pause requested');
        end
        
        function data = GetData(obj,stage,imager)
            if ~isempty(obj.scan)
                data = object2struct(obj,{'rl','gl','nidaq','galvos','WinSpec','wavemeter','listeners','path_button','pb'});
            else
                data = [];
            end
        end
        function settings(obj,panelH)
            spacing = 2.25;
            num_lines = 2;
            line = 1;
            uicontrol(panelH,'style','checkbox','string','Take New Image','horizontalalignment','right',...
                'units','characters','position',[5 spacing*(num_lines-line) 30 1.25],...
                'callback',@obj.newImageCallback,'value',obj.newImage);
            line = 2;
            tip = fullfile(obj.WinSpec.remoteDrive,obj.WinSpec.path);
            obj.path_button = uicontrol(panelH,'style','PushButton','String','Spec Path','tooltipstring',tip,...
                'units','characters','position',[5 spacing*(num_lines-line) 20 2],...
                'callback',@obj.change_spec_path);
        end
        function newImageCallback(obj,hObj,~)
            obj.newImage = hObj.Value;
        end
        function change_spec_path(obj,hObj,varargin)
            folder_name = uigetdir(fullfile(obj.WinSpec.remoteDrive,obj.WinSpec.path),'Spectrometer Directory');
            if folder_name
                folder_name = folder_name(3:end); % Remove drive letter
                obj.WinSpec.path = folder_name;
            end
        end
        function SpecPathSet(obj,src,eventData)
            if ~isempty(obj.path_button) && isvalid(obj.path_button)
                obj.path_button.TooltipString = fullfile(obj.WinSpec.remoteDrive,obj.WinSpec.path);
            end
        end
        function output = get.spec2wave(obj)
            temp = obj.spec2wave;
            if isempty(temp)
                error('No spec2wave calibration available')
            end
            cal_timer = hours(datetime('now')-temp.datetime);
            if cal_timer > obj.cal_timeout
                warning(sprintf('Spectrometer has not been calibrated with wavemeter in %g hours.',cal_timer));
            end
            output = temp.cal_func;
        end
        function set.spec2wave(obj,cal)
            stack = dbstack;
            if ~sum(strcmpi('AutoSlowScan.instance',{stack.name})) %if not in the instantiator
                temp.cal_func = cal;
                temp.datetime = datetime('now');
                obj.spec2wave = temp;
            else
                obj.spec2wave = cal; %if in the instantiator, just grab old struct
            end
        end
    end
end
