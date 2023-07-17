classdef PVCAM < Modules.Imaging
    %PVCAM Uses third party C drivers to connect to Photometrics Cameras.
    %   (Implementation incomplete, and may only work with older cameras).
    %   Code is unclean. Must be ritually purified.

    properties
        maxROI = [-1 1; -1 1];
    end
    properties (Hidden)
        h_cam;
        prefs = {'gain', 'speed', 'binning', 'exposure', 'frames'};
    end
    properties(GetObservable,SetObservable)
        camera_name =   Prefs.String('', 'help_text', 'Camera name assigned by PVCAM.', 'readonly', true);
        width =         Prefs.Integer(0, 'units', 'pix', 'help_text', 'Width that the camera thinks it has.', 'readonly', true);
        height =        Prefs.Integer(0, 'units', 'pix', 'help_text', 'Height that the camera thinks it has.', 'readonly', true);
        temp =          Prefs.Double(0,  'units', 'C',   'help_text', 'Temp that the camera thinks it is at.', 'readonly', true);

        gain =          Prefs.MultipleChoice(3, 'choices', {1, 2, 3},   'allow_empty', false, 'set', 'set_gain',    'help', 'EM (electron multipying) gain. Higher levels imply more gain.'); % Add description
        speed =         Prefs.MultipleChoice(0, 'choices', {0},         'allow_empty', false, 'set', 'set_speed',   'help', 'Readout mode; 0 = fast?');
        EMgain =          Prefs.Integer(1, 'units', 'EM gain multiplier',  'help_text', 'EM gain multiplication factor', 'set', 'set_EMgain'); % EM gain setting
        
        binning =       Prefs.MultipleChoice(1, 'choices', {1, 2, 3, 4},      'allow_empty', false, 'units', 'pix',       'help_text', 'Binning N =/= 1 will cause the camera to aquire data in N x N superpixels. High N means faster readout, but also reduced resolution.');   % This is camera-dependent...
        exposure =      Prefs.Double(1000, 'min', 0, 'units', 'ms', 'help_text', 'Integration time for each frame.'); % Add better limits.
        frames =        Prefs.Integer(1,   'min', 0, 'units', '#',  'help_text', 'Number of 2D frames snapped per cycle. Frames > 1 will allow the camera to aquire data faster.');
        
        resolution = [128 128];                 % Pixels
        ROI = [-1 1; -1 1];
        continuous = false;
    end

    methods(Access=private)
        function obj = PVCAM()
            obj.open();
        end
        function open(obj)
            camnum = 0;
            obj.path = 'camera';
            
            % open camera
            obj.h_cam = pvcamopen(camnum);
            
            if (isempty(obj.h_cam))
                try
                    pvcamclose(camnum);
                    obj.h_cam = pvcamopen(camnum);
                    
                    if (isempty(obj.h_cam))
                        error('Could not open PVCAM');
                    end
                catch
                    error('Could not open PVCAM');
                end
            end
            
            obj.camera_name = num2str(obj.h_cam);
            obj.loadPrefs;
            
            obj.getParams();
        end
        function getParams(obj)
            % some parameters
            pvcam_getpar = {'PARAM_BIT_DEPTH', 'PARAM_CHIP_NAME', ...
                'PARAM_PAR_SIZE', 'PARAM_SER_SIZE', 'PARAM_PREMASK', 'PARAM_TEMP', 'PARAM_GAIN_INDEX',...
                'PARAM_PIX_TIME','PARAM_EXP_RES','PARAM_PIX_TIME','PARAM_GAIN_MULT_FACTOR'};
            pvcam_setpar = {'PARAM_CLEAR_MODE', 'PARAM_CLEAR_CYCLES', 'PARAM_GAIN_INDEX', ...
                'PARAM_PMODE', 'PARAM_SHTR_OPEN_MODE', 'PARAM_SHTR_CLOSE_DELAY', 'PARAM_SHTR_OPEN_DELAY', ...
                'PARAM_SPDTAB_INDEX', 'PARAM_TEMP_SETPOINT','PARAM_PIX_TIME'};

            pvcam_para_value = {[],[],[],[],[],[],[],[]};
            pvcam_para_field = {'serdim','pardim','gain','speedns','timeunit','temp','readout','EMgain'};
            pvcam_par = cell2struct(pvcam_para_value, pvcam_para_field, 2);
            
            pvcam_par.serdim   = pvcamgetvalue(obj.h_cam, pvcam_getpar{4});%CCDpixelser
            pvcam_par.pardim   = pvcamgetvalue(obj.h_cam, pvcam_getpar{3});%CCDpixelpar
            [pvcam_par.gain, ~, ~, gainrange] = pvcamgetvalue(obj.h_cam, pvcam_getpar{7});%CCDgainindex
            pvcam_par.speedns  = pvcamgetvalue(obj.h_cam, pvcam_getpar{8});%CCDpixtime
            pvcam_par.timeunit = pvcamgetvalue(obj.h_cam, pvcam_getpar{9});%CameraResolution
            pvcam_par.temp     = pvcamgetvalue(obj.h_cam, pvcam_getpar{6});%temperature
            pvcam_par.readout  = pvcamgetvalue(obj.h_cam, pvcam_getpar{10});%readout rate 50 means 20MHz, 100 means 10MHz
            [pvcam_par.EMgain, ~, ~, gainrange2]  = pvcamgetvalue(obj.h_cam, pvcam_getpar{11});%EM gain setting

            gainrange
            gainrange2
            
            obj.width = pvcam_par.serdim;
            obj.height = pvcam_par.pardim;
            obj.resolution = [obj.width, obj.height];
            obj.ROI = [0, obj.width-1; 0, obj.height-1];
            obj.maxROI = obj.ROI;
            
            obj.gain = pvcam_par.gain;
            obj.temp = pvcam_par.temp/100;
            
            obj.EMgain = pvcam_par.EMgain;
            
            if ~contains(pvcam_par.timeunit, 'One Millisecond')
                 warning([datestr(datetime('now')) ':NOT in milliseconds!']);
            end
        end
        function close(obj)
            if (~isempty(obj.h_cam))
                pvcamclose(0);
                obj.h_cam = [];
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.PVCAM();
            end
            obj = Object;
        end
    end
    methods
        function val = set_gain(obj, val, ~)
            if ~isempty(obj.h_cam)
                pvcamsetvalue(obj.h_cam, 'PARAM_GAIN_INDEX', val);
            end
        end
        function val = set_speed(obj, val, ~)
            if ~isempty(obj.h_cam)
                pvcamsetvalue(obj.h_cam, 'PARAM_SPDTAB_INDEX', val);
            end
        end
        function val = set_EMgain(obj, val, ~)
            if ~isempty(obj.h_cam)
                pvcamsetvalue(obj.h_cam, 'PARAM_GAIN_MULT_FACTOR', val);
            end
        end

        
        function delete(obj)
            obj.close();
        end
        
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
        function focus(obj,ax,stageHandle)
        end
        function im = snapImage(obj)
            ni = obj.frames; % Number of images.
            
            roi_name = {'s1','s2','sbin','p1','p2','pbin'};
            roi_value = {0, obj.width-1, obj.binning, 0, obj.height-1, obj.binning};   % Zero indexed.
            roi_struct = cell2struct(roi_value, roi_name, 2);
            
            w = floor((roi_struct.s2 - roi_struct.s1+1)/roi_struct.sbin);
            h = floor((roi_struct.p2 - roi_struct.p1+1)/roi_struct.pbin);
            
            im = NaN([w, h, ni]);
            
            tries = 1;
            while tries <= 3
                image_stream = uint16(pvcamacq(obj.h_cam, ni, roi_struct, obj.exposure, 'timed'));
                
                if ~isempty(image_stream)
                    im = reshape(image_stream, [w, h, ni]);
                    break;
                else
                    warning('PVCAM returned empty data. Resetting and retrying.');
                    resettries = 1;
                    while resettries <= 3
                        pause(2^resettries)
                        try
                            obj.close();
                            obj.open();
                        catch err
                            disp(getReport(err, 'extended', 'hyperlinks', 'on'));
                        end
                        resettries = resettries + 1;
                    end
                end
                
                tries = tries + 1;
            end
        end
        function snap(obj,im,continuous)
            img = obj.snapImage();
            set(im,'cdata',double(img(:,:,1)));
        end
        
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                try
                    obj.snap(im,true);
                    drawnow;
                catch err
                    obj.continuous = false;
                end
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
        end

    end

end