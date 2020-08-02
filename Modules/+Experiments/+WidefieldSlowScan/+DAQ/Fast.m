classdef Fast < Experiments.WidefieldSlowScan.DAQ.DAQ_invisible
   
    properties(GetObservable, SetObservable, AbortSet)
        DAQ_sync = Prefs.String('pvcam exposure PFI',                                            'help', 'Timing signal from the camera. Must be a PFI port.');
        
        fast_range =  Prefs.Double(1e3, 'min', 0, 'unit', 'MHz', 'set', 'calc_pointsrate',       'help', 'Range of fast scan. This is in MHz because sane units are sane.');
        fast_step =   Prefs.Double(10,  'min', 0, 'unit', 'MHz', 'set', 'calc_pointsrate',       'help', 'Step between frequency points of fast scan. This is in MHz because sane units are sane.');
        fast_time =   Prefs.Double(1,   'min', 0, 'unit', 'sec', 'set', 'calc_pointsrate',       'help', 'Time for each fast scan.');
        fast_scans =  Prefs.Integer(1,  'min', 1, 'unit', '#',   'set', 'zigzageven',            'help', 'Number of fast scans per measurement.');

        fast_points = Prefs.Integer(2, 'readonly', true, 'unit', '#',       'help', 'Data aquisition numpoints imposed by range, step, and time.');
        fast_rate =   Prefs.Double( 0, 'readonly', true, 'unit', 'fps',     'help', 'Data aquisition rate imposed by range, step, and time.');
        
        zigzag = Prefs.Boolean(true, 'help', 'If true, the scan will zigzag to minimize shock to the laser. If false, the scan will sawtooth. If this is enabled, fast_scans must be even.');
    end
    
    methods(Access=private)
        function obj = Fast()
            obj.prefs = [obj.prefs,{'DAQ_sync','fast_range','fast_step','fast_time','fast_scans','zigzag'}];
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.calc_pointsrate(0,0);
        end
    end
    
    methods(Static)
        function obj = instance(varargin)
            % This file is what locks the instance in memory such that singleton
            % can perform properly. 
            % For the most part, varargin will be empty, but if you know what you
            % are doing, you can modify/use the input (just be aware of singleton_id)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Experiments.WidefieldSlowScan.DAQ.Fast.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.WidefieldSlowScan.DAQ.Fast(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
    end
    
    methods
        
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;

%             try
                obj.PreRun(status,managers,ax);
                
                w = obj.imaging.width;
                h = obj.imaging.height;
                
                if ~obj.only_get_freq
                    obj.data.images = zeros([w, h, obj.fast_points, obj.fast_scans, length(obj.scan_points)], 'int16');
                end
                
                freq_check_points = min(10, obj.fast_points);
                
                if obj.save_freq
                    obj.data.freqs_measured_IR =    NaN(length(obj.scan_points), 2*freq_check_points);
                    obj.data.freqs_measured =       NaN(length(obj.scan_points), 2*freq_check_points);
                end
                
                wm6 = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 6, true);
                wm7 = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 7, true);
                
                wm6.SetSwitcherSignalState(1);
                wm7.SetSwitcherSignalState(1);
                
                for ii = 1:length(obj.scan_points)
                    obj.data.experiment_time(ii) = now;
            
%                     status.String = sprintf('Progress (%i/%i pts):\n  Setting laser', ii, length(obj.scan_points));
%                     toc


                    if ~obj.only_get_freq
                        drawnow
                        if ~obj.repump_always_on
                            obj.repumpLaser.on  % Repump laser on during freq sweep.
                        end
                    end

                    % Setup voltage sweep.
                    V0 = obj.scan_points(ii);
                    dV = obj.fast_range / obj.V2GHz / 1e3;
                    
                    % ...
                    if obj.save_freq
                        Vwl = linspace(V0-dV/2, V0+dV/2, freq_check_points);
                        if obj.zigzag
                            Vwl = [Vwl, Vwl(end:-1:1)];
                        else
                            Vwl = [Vwl, Vwl];
                        end
                        
                        for jj = 1:length(Vwl)
                            obj.setLaser(Vwl(jj));
                            pause(.05);
                            drawnow
                            obj.data.freqs_measured_IR(ii, jj) =    wm6.getFrequency();
                            obj.data.freqs_measured(ii, jj) =       wm7.getFrequency();
                            status.String = sprintf('Progress (%i/%i pts):\n  Measuring laser (%i/%i pts, V = %.2f, f_VIS = %.4f, f_IR = %.4f )',...
                                ii, length(obj.scan_points), jj, length(Vwl), Vwl(jj),obj.data.freqs_measured(ii, jj), obj.data.freqs_measured_IR(ii, jj));
                        end
                    end
                    obj.data.Vwl(:,ii) = Vwl;

                    V = linspace(V0-dV/2, V0+dV/2, obj.fast_points);
                    if obj.zigzag       % Up (zig) and back down (zag)
                        V = [V, V(end:-1:1)];
                        V = repmat(V, [1, floor(obj.fast_scans/2)]);
                    else                % Sawtooth
                        V = repmat(V, [1, obj.fast_scans]);
                    end
                    V = V';
                    
                    obj.data.V(:,ii) = V;

                    % Setup DAQ.
                    obj.dev.ClearAllTasks();
                    task = obj.dev.CreateTask('PVCAMpulsetrainTest');
                    task.ConfigureVoltageOutExtTiming(obj.DAQ_line, V, obj.DAQ_sync, 'falling');    % Trigger step on the falling edges of the camera pulses.
                    task.Start();

                    % Setup camera.
                    obj.imaging.frames = length(V) + 1;
                    ms = (1000/obj.fast_rate) - 2;  % 2 ms camera overhead. Future: don't hardcode this.
                    if ms < 10
                        warning('Camera expoure will be less than 10 ms.');
                    end
                    obj.imaging.exposure = ms;
                    
                    
                    if ~obj.repump_always_on
                        obj.repumpLaser.off
                    end

                    % Activate.
                    status.String = sprintf('Progress (%i/%i pts):\n  Snapping image (laser at %f)\n %i x (%.1f+2) ms exposure = %.2f sec',...
                                            ii, length(obj.scan_points), obj.data.freqs_measured(ii,1), length(V), ms, length(V)*(ms+2)/1e3);
                    drawnow;
                    img = obj.imaging.snapImage;
                    obj.data.images(:,:,:,:,ii) = reshape(img(:,:,2:end), [w, h, obj.fast_points, obj.fast_scans]) ;
                    
                    obj.data.done(ii) = task.IsTaskDone()
                    task.Stop();
                    task.Clear();
                    
                    % Flip the zags.
                    if obj.zigzag
%                         size(obj.data.images(:,:,:,2:2:end,ii))
%                         size(obj.data.images(:,:,:,end:-2:2,ii))
                        obj.data.images(:,:,:,2:2:end,ii) = obj.data.images(:,:,:,end:-2:2,ii);
                    end
                    
                    ax.UserData.CData = mean(img(:,:,2:end), 3);
                    status.String = sprintf('Progress (%i/%i pts):\n  Snapped image', ii, length(obj.scan_points));
                    drawnow
                    
%                     if ~obj.only_get_freq
%                         drawnow
%                         if ~obj.repump_always_on
%                             obj.repumpLaser.on
%                         end
%                     end
%                     
%                     try
%                         if obj.abort_request
%                             break;
%                         end
%                     
%                         tic
%                         obj.setLaser(obj.scan_points(ii));
%                         obj.data.freqs_time(ii) = toc;
%                     
%                         if obj.save_freq
%                             obj.data.freqs_measured(ii) = obj.resLaser.getFrequency();
%                         end
%                         
%                         if obj.abort_request
%                             break;
%                         end
% 
%                         if obj.only_get_freq
%                             status.String = sprintf('Progress (%i/%i pts):\n  Laser set %f (laser at %f)', ii, length(obj.scan_points), obj.scan_points(ii), obj.data.freqs_measured(ii));
%                             drawnow
%                         else
%                             if ~obj.repump_always_on
%                                 obj.repumpLaser.off
%                             end
% 
%                             if obj.save_freq
%                                 status.String = sprintf('Progress (%i/%i pts):\n  Snapping image (laser at %f)', ii, length(obj.scan_points), obj.data.freqs_measured(ii));
%                             else
%                                 status.String = sprintf('Progress (%i/%i pts):\n  Snapping image', ii, length(obj.scan_points));
%                             end
%                             drawnow
%                             
%                             obj.data.images(:,:,ii) = obj.imaging.snapImage;
%                             ax.UserData.CData = obj.data.images(:,:,ii);
%                         end
%                     
%                         if obj.save_freq
%                             obj.data.freqs_measured_after(ii) = obj.resLaser.getFrequency();
%                         end
%                     catch err
%                         warning(err.message)
%                     end
                    
                    if obj.abort_request
                        break;
                    end
                end

%             catch err
%                 warning(err.message)
%             end
            
            obj.PostRun();
            
            if exist('err','var')
                rethrow(err)
            end
        end
        
        function val = calc_pointsrate(obj, val, ~)
            obj.fast_points = max(2,  floor(obj.fast_range / obj.fast_step + 1));
            obj.fast_rate = obj.fast_points / obj.fast_time;
        end
        function val = zigzageven(obj, val, ~)
            if mod(val, 2)              % If odd number of scans ...
                obj.zigzag = false;     % ... then should not zigzag
            end
        end
    end
end