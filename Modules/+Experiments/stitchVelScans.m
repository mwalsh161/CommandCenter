classdef stitchVelScans < Modules.Experiment
    %velocity scan over a large range.
    %stitches together many piezo scans by setting the motor.
    
    properties
        dwell = 0.1;        % ms, dwell time for APDs
        scanResolution = 20e-5; %resolution for each scan.
        nSamples = 10;      % number of samples at each point
        startLam = 635.5;        % nm starting wavelength
        stopLam = 637.0;
        singleSpan = 0.02;      %scan range for the piezo scans (default = 20GHz)
        slow = 1;
        c = 299792458; % speed of light
        APD_line = 'APD1'; % APD line name (for counter)
        data
        prefs = {'dwell','scanResolution','nSamples','startLam','stopLam','singleSpan','slow','nFreqs'};
    end
    
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        vel   % Velocity
        counter
    end
    
    methods(Access=private)
        function obj = stitchVelScans()
            obj.vel = Sources.VelocityLaser.instance;
            obj.counter = Drivers.Counter.instance(obj.APD_line,'CounterSync'); 
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.stitchVelScans();
            end
            obj = Object;
        end
    end
    
    methods
        function run(obj,statusH,managers,ax)
            obj.abort_request=false;
            if obj.slow
                obj.runSlow(statusH,ax);
            else
                obj.runFast;
            end
        end
        
        function runSlow(obj,statusH,ax)
            %Does a slow, careful scan across the full region.
            %Final list should be continuous and in order.
            
            %set initial values & initialize frequency list
            startFreq = obj.c*1e-12/(max(obj.startLam,obj.stopLam)*1e-9); %freq in THz
            stopFreq = obj.c*1e-12/(min(obj.startLam,obj.stopLam)*1e-9); %freq in THz
            
            nTotal = round((stopFreq-startFreq+obj.singleSpan)/obj.scanResolution);
            totalFreqs = linspace(startFreq-obj.singleSpan/2.0,stopFreq+obj.singleSpan/2.0,nTotal);
            
            counts = NaN(1,nTotal);
            norm = NaN(1,nTotal);
            obj.data = [totalFreqs; counts; norm];
            d=0;
            
            nCoarse = round((stopFreq-startFreq)/obj.singleSpan);
            coarseFreqs = linspace(startFreq,stopFreq,nCoarse);
            
            nFine = round(obj.singleSpan/obj.scanResolution);
           
            for i = 1:nCoarse
                %try to move the motor to the first center frequency
                currFreq = coarseFreqs(i);
                obj.vel.LaserMove(currFreq);
                
                set(statusH,'string',...
                        sprintf('At point %i out of %i at freq%f2',i,nCoarse,currFreq));
                fineFreqs = linspace(currFreq-obj.singleSpan/2.0,currFreq+obj.singleSpan/2.0,nFine);
                
                for k = 1:nFine;
                    d=d+1;
                    assert(~obj.abort_request,'User aborted');
                    try
                        obj.vel.LaserSetpoint(fineFreqs(k));
                    catch
                        continue
                    end
                    %record APD counts.
                    samples = obj.counter.singleShot(obj.dwell,obj.nSamples);
                    obj.data(2,d) = sum(samples);
                    obj.data(3,d) = obj.vel.wavemeter.getPower;
                end
                plot(obj.data(1,:),obj.data(2,:)./obj.data(3,:),'Parent',ax);
            end   
        end
        
        function runFast(obj,statusH,ax)
            %does a quick scan over a large region
            %no PID control for either motor or piezo movement, so scans
            %are only approximately as set at best. However it will read
            %and record the actual frequency so the final data will be
            %correct.
            
            startFreq = obj.c*1e-12/(max(obj.startLam,obj.stopLam)*1e-9); %freq in THz
            stopFreq = obj.c*1e-12/(min(obj.startLam,obj.stopLam)*1e-9); %freq in THz
            
            nFine = 90; %sweep from 5 to 95% in steps of 1 percent.
            percents = linspace(5,95,90);
            
            nCoarse = (startFreq-stopFreq)/obj.singleSpan;
            coarseFreqs = linspace(startFreq,stopFreq,nCoarse);
            
            nTotal = nCoarse*nFine;
            freqs = NaN(1,nTotal);
            counts = NaN(1,nTotal);
            norm = NaN(1,nTotal);
            obj.data = [totalFreqs; counts; norm];
            d=0;
            
            
            for i = 1:nCoarse
                %move motor without feedback to approximately the right
                %frequency.
                obj.vel.LaserMoveCoarse(coarseFreqs(i));
                obj.serial.TrackMode = 'off';
                
                for k = 1:nFine
                    d=d+1;
                    assert(~obj.abort_request,'User aborted');
                    try
                        obj.vel.LaserOffset(percents(k));
                    catch
                        continue
                    end
                    %record APD counts.
                    samples = obj.counter.singleShot(obj.dwell,obj.nSamples);
                    obj.data(1,d) = obj.vel.wavemeter.Frequency;
                    obj.data(2,d) = sum(samples);
                    obj.data(3,d) = obj.vel.wavemeter.getPower;
                end
                plot(obj.data(1,:),obj.data(2,:),'Parent',ax);
                hold on;
                plot(obj.data(1,:),obj.data(2,:)./obj.data(3,:),'Parent',ax);
            end
            
            
        end
        
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data = obj.data;
            else
                data = [];
            end
        end
        
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 5;
            line = 1;
            uicontrol(panelH,'style','text','string','Start Wavelength:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.startLam),'tag','startLam',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','Stop Wavelength:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.stopLam),'tag','stopLam',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string','Scan Resolution (THz):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 24 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.scanResolution),'tag','scanResolution',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[25 spacing*(num_lines-line) 10 1.5]);
            line = 4;
            uicontrol(panelH,'style','text','string','Single Scan Span:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.singleSpan),'tag','singleSpan',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 5;
            uicontrol(panelH,'style','checkbox','string','Slow Scan','horizontalalignment','right',...
                'units','characters','position',[2 spacing*(num_lines-line) 18 1.25],...
                'value',obj.slow,'callback',@obj.slowCallback);
            
        end
        function setNum(obj,hObj,~)
            temp = get(hObj,'string');
            temp = str2double(temp);
            assert(~isnan(temp),'Must be a number!');
            obj.(get(hObj,'tag')) = temp;
        end
        function slowCallback(obj,hObj,~)
            if ~obj.slow && get(hObj,'Value') % Going from not using to using
                warndlg('Might need to reload this module after enabling slow scans.')
            end
            obj.slow = get(hObj,'Value');
        end
    end
    
end