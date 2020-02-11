classdef Micromanager_camera_invisible < Imaging.Camera.Cameras_invisible
    %Micromanager Camera Control Superclass
    
    
    properties
        property_cell_array = [];
        prefs = {'property_cell_array'};
    end
    
    properties(Hidden)
        panel_handle
    end
    
    properties(Access=private)
        videoTimer
        core
    end
    
    properties(SetObservable)
        resolution = [NaN NaN]; % Set in constructor and set_binning
        ROI              % Region of Interest in pixels [startX startY; stopX stopY]
        continuous = false;
    end
    
    methods
        function obj = Micromanager_camera_invisible()
            % Initialize Java Core
            try
                addpath(obj.device_path)
                import('mmcorej.*');
                
            catch
                error('Your device path for your mmcorej object is incorrect.')
            end
            
            try
                core=CMMCore;
            catch
                error('Have not initialized CMMCORE object. Try installing micromanager into Matlab.')
            end
            try
                core.loadSystemConfiguration(fullfile(obj.device_path,[obj.dev_filename,'.cfg']));
            catch
                error('Your device name is incorrect check your cfg file.')
            end
            obj.core = core;
            
            % Load preferences
            %             if isempty(obj.property_cell_array)
            obj.determine_property_info(); %read in property array from camera
            %             else
            obj.set_all_properties
            %             end
            
            %set buffer limit
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            obj.core.clearROI();
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            ROI= obj.core.getROI();
            obj.maxROI = [ROI.x, ROI.x+ROI.width;...
                ROI.y,ROI.y+ROI.height]*obj.getBinning;
        end
        
    end
    
    methods (Access=private)
        
        function determine_property_info(obj)
            props = obj.core.getDevicePropertyNames(obj.dev);
            numprops = props.size();  % # Indexed from 0!
            obj.property_cell_array = [];
            for index=0:numprops-1
                current_val = char(obj.core.getProperty(obj.dev,props.get(index)));
                property = [];
                property.name = char(props.get(index));
                property.display_name = property.name;
                max_character_length = 15;  %crop the length of a property name so that it can be displayed
                if numel(property.display_name)>max_character_length
                    property.display_name = property.display_name(1:max_character_length);
                end
                choices = [];
                if obj.core.isPropertyReadOnly(obj.dev,props.get(index))
                    property.style = 'text';      
                    property.default = current_val;
                else
                    java_string = obj.core.getAllowedPropertyValues(obj.dev,props.get(index));
                    choices_for_property = double(java_string.size);                    
                    if choices_for_property > 1
                        property.style = 'popup';
                        for index2=0:choices_for_property-1
                            choices{index2+1}=char(java_string.get(index2));
                        end
                        property.options = choices;
                        property.default = find(contains(property.options,current_val));
                        assert(~isempty(property.default),[current_val,' is not a valid property value for property: ',property.name])
                    else
                        property.style = 'edit';
                        if isempty(str2num(current_val))
                           property.default = current_val;
                        else
                            property.default = str2num(current_val);
                        end
                    end
                end
                obj.property_cell_array{index+1} = property;
            end
        end
        
        function set_all_properties(obj)
            for index = 1:numel(obj.property_cell_array)
                property = obj.property_cell_array{index};
                name = property.name;
                switch property.style
                    case 'text'
                        value = property.default;
                        if ~isempty(obj.panel_handle)&& isvalid(obj.panel_handle)
                            obj.panel_handle.UserData.update(obj.panel_handle,name,value);
                        end
                    case 'edit'
                        value = property.default;
                        obj.setProperty(name,value);
                    case 'popup'
                        value = property.options{property.default};
                        obj.setProperty(name,value);
                end
            end
        end
        
       
        function grabFrame(obj,~,~,hImage)
            % Timer Callback for frame acquisition
            if obj.core.isSequenceRunning()&&obj.core.getRemainingImageCount()>0
                dat = obj.core.popNextImage();
                width = obj.core.getImageWidth();
                height = obj.core.getImageHeight();
                dat = reshape(dat, [width, height]);
                set(hImage,'cdata',dat);
            end
            drawnow;
        end
        
        function update_property_cell_array(obj,property_name,val)
            for index = 1:length(obj.property_cell_array)
                property = obj.property_cell_array{index};
                if strcmp(property_name,property.name)
                    switch property.style
                        case 'edit'
                            property.default = val;
                        case 'popup'
                            property.default = find(contains(property.options,val));
                        otherwise
                            error(['unsupported property style while trying to update property'...
                                ' cell array'])
                    end
                    obj.property_cell_array{index} = property;
                    return
                end
            end
        end
        
        function val = property_change(obj,hObj,eventData)
            property_name=hObj.Tag;
            value=eventData.new_value;
            wasRunning = false;
            if strcmp(eventData.previous_value,eventData.new_value)
                % Case of no change
                val = eventData.previous_value;
                return;
            else
                if obj.core.isSequenceRunning()
                    % Pause camera acquisition, but leave the video going
                    % (just wont be frames until we resume acquisition)
                    obj.core.stopSequenceAcquisition();
                    wasRunning = true;
                end
                obj.setProperty(property_name,value);
                obj.determine_property_info; %properties can be dependant on one another so determine current state of camera values
                obj.set_all_properties; %set all values
                val = obj.getProperty(property_name);
                if wasRunning
                    obj.core.startContinuousSequenceAcquisition(0); %restart camera sequence
                end
            end
        end
        
    end
    
    methods
        %handle setting properties
      function set.ROI(obj,val)
            % Because this has a draggable rectangle in CommandCenter, it
            % is best to not stop and start acquisition like we do with
            % exposure and binning
            assert(~obj.core.isSequenceRunning(),'Cannot set while video running.')
            % Use the full ROI as bounds
            obj.core.clearROI();
            roi = obj.core.getROI();
            xstart = max(roi.x,val(1));
            ystart = max(roi.y,val(2));
            width = min(roi.width-xstart,val(3)-xstart);
            height = min(roi.height-ystart,val(4)-ystart);
            obj.core.setROI(xstart,ystart,width,height);
            %% check if setROI was successful
            
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
        end
        
        function val = get.ROI(obj)
            val = obj.core.getROI();
            val = [val.x val.x+val.width; val.y val.y+val.height];
            val = val + obj.CamCenterCoord.'*ones(1,2);
            val = val/obj.calibration;
        end  
        
         function setProperty(obj,prop_name,value)
            current_value=obj.getProperty(prop_name);
            if ~strcmp(current_value,value)
                obj.core.setProperty(obj.dev,prop_name,value);
                obj.update_property_cell_array(prop_name,value);
            else
                return
            end
            if ~isempty(obj.panel_handle)&& isvalid(obj.panel_handle)
                obj.panel_handle.UserData.update(obj.panel_handle,prop_name,value);
            end
            if strcmp(prop_name,'Binning')
                res(1) = obj.core.getImageWidth();
                res(2) = obj.core.getImageHeight();
                obj.resolution = res;
                ROI=obj.core.getROI;
                obj.ROI=[ROI.x,ROI.x+ROI.width;ROI.y,ROI.y+ROI.height];
            end
        end
        
        function val = getProperty(obj,prop_name)
            val=char(obj.core.getProperty(obj.dev,prop_name));  
        end
        
        
    end
    
    methods
        %% these are the abstract methods described in the Imaging Module.
        function metric = focus(obj,ax,Managers)
            error('Not Implemented!')
        end
        
        function startVideo(obj,hImage)
            obj.continuous = true;
            if obj.core.isSequenceRunning()
                warndlg('Video already started.')
                return
            end
            obj.setTrigMode('Internal');
            obj.core.startContinuousSequenceAcquisition(100);
            obj.videoTimer = timer('tag','Video Timer',...
                'ExecutionMode','FixedSpacing',...
                'BusyMode','drop',...
                'Period',0.01,...
                'TimerFcn',{@obj.grabFrame,hImage});
            start(obj.videoTimer)
        end
        
        function stopVideo(obj)
            if ~obj.core.isSequenceRunning()
                warndlg('No video started.')
                obj.continuous = false;
                return
            end
            obj.core.stopSequenceAcquisition();
            stop(obj.videoTimer)
            delete(obj.videoTimer)
            obj.continuous = false;
        end
        
        function dat = snap(obj,varargin)
            if strcmp(obj.getTrigMode,'External Exposure') || strcmp(obj.getTrigMode,'External Start') || (obj.core.isSequenceRunning()&& obj.core.getRemainingImageCount()>0)
                dat=obj.core.popNextImage;
            else
                obj.core.snapImage();
                dat = obj.core.getImage();
            end
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            dat = reshape(dat, [width, height]);
            if nargin>1
                hImage=varargin{1};
                set(hImage,'cdata',dat)
                axis image
                axis xy
                axis(hImage,'image');
                drawnow
            end
        end
    end
    
    methods
        %% general methods
        
        function delete(obj)
            if obj.core.isSequenceRunning()
                obj.stopVideo;
            end
            obj.core.reset()  % Unloads all devices, and clears config data
            delete(obj.core)
        end
        
        function reset(obj,varargin)
            if obj.core.isSequenceRunning || obj.continuous
                obj.core.stopSequenceAcquisition();
                obj.continuous = 0;
            end
            obj.setTrigMode('Internal');
            obj.setExposure(30)
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            if nargin >1
                obj.setBinning(varargin{1})
            end
            obj.snap; %take an image to clean circular buffer
        end
        
        function startSequenceAcquisition(obj,Num_images,varagin)
            narginchk(1,3)
            if nargin == 2
                obj.setTrigMode('External Exposure');
            else
                obj.setTrigMode(varagin);
            end
            BytesPerPixel = obj.core.getBytesPerPixel();
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            pixels_per_image = width*height;
            bits_per_image = pixels_per_image*BytesPerPixel;
            bits_per_image = 3./obj.getBinning; %chris modified this to be 3 Megabytes divided by binning
            obj.core.setCircularBufferMemoryFootprint(bits_per_image*Num_images);
            max_num_images = obj.core.getBufferTotalCapacity();
            assert(Num_images<max_num_images,'requested images count is greater than that supported by the camera.')
            obj.core.startSequenceAcquisition(Num_images,0,1);
        end
        
        function dat_matrix = stopSequenceAcquisition(obj,Num_images)
            if strcmp(obj.getTrigMode,'Internal') 
                dat_matrix = [];
                return
            end
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            dat_matrix=nan(width,height,Num_images);%preallocate for speed
            for frame = 1:Num_images
                dat=[];
                try
                    dat = obj.snap;
                catch
                    error('Camera failed to return the expected number of images.Possibly missed a trigger.')
                end
                dat_matrix(:,:,frame)=dat;
            end
            obj.core.stopSequenceAcquisition;
            obj.reset;
            if isempty(dat_matrix)
                dat_matrix=[];
            end
        end
        
        %% set methods
        
        function setExposure(obj,Exposure)
            assert(~obj.core.isSequenceRunning,'Cannot change exposure when sequence is running')
            assert(isa(Exposure,'double'),'value for camera''s exposure must be a double!')
            assert(Exposure>0,'Exposure must be a value greater than 0')
            Exposure=num2str(Exposure);
            obj.setProperty('Exposure',Exposure);
        end
        
        function setEMGain(obj,Gain)
            assert(~obj.core.isSequenceRunning,'Cannot change gain when sequence is running')
            assert(isa(Gain,'double'),'value for camera''s Gain must be a double!')
            assert(mod(Gain,1)==0,'Gain must be an integer.')
            assert(Gain>=0,'Gain must be a value greater or equal to 0')
            if Gain==0
                obj.setProperty('EMSwitch','Off');
                return
            else
                obj.setProperty('EMSwitch','On');
            end
            Gain=num2str(Gain);
            obj.setProperty('Gain',Gain);
        end
        
        function setGain(obj,Gain)
            assert(~obj.core.isSequenceRunning,'Cannot change gain when sequence is running')
            assert(isa(Gain,'double'),'value for camera''s Gain must be a double!')
            assert(mod(Gain,1)==0,'Gain must be an integer.')
            assert(Gain>0,'Gain must be a value greater than 0')
            obj.setProperty('Pre-Amp-Gain',num2str(Gain));
        end
        
        function setTrigMode(obj,trig_mode)
            assert(~obj.core.isSequenceRunning,'Cannot change trig_mode when sequence is running')
            assert(ischar(trig_mode),'trig_mode must be a character')
            switch trig_mode
                case {'External Start'}
                case {'Internal'}
                case {'External Exposure'}
                otherwise
                    error('unknown trigger mode. Trig modes are: Internal, External Exposure, and External Start.')
            end
            obj.setProperty('Trigger',trig_mode);
        end
        
        function setBinning(obj,binning)
            assert(~obj.core.isSequenceRunning,'Cannot change binning when sequence is running')
            assert(isa(binning,'double'),'value for camera''s Gain must be a double!')
            assert(mod(binning,1)==0,'Binning must be an integer.')
            assert(binning>0,'Binning must be a value greater than 0')
            
            obj.setProperty('Binning',num2str(binning));
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            ROI=obj.core.getROI;
            obj.ROI=[ROI.x,ROI.x+ROI.width;ROI.y,ROI.y+ROI.height];;
        end
        %% get methods
        
        function Exposure = getExposure(obj)
            Exposure = obj.getProperty('Exposure');
            Exposure = str2num(Exposure);
        end
        
        function Gain = getEMGain(obj)
            EMSwitch_state = obj.getProperty('EMSwitch');
            if strcmp(EMSwitch_state,'Off')
                Gain = 1;
                return
            end
            Gain = obj.getProperty('Gain');
            Gain = str2num(Gain);
        end
        
        function Gain = getGain(obj)
           Gain = obj.getProperty('Pre-Amp-Gain');
           Gain = str2num(Gain(1:end - 1)); %get rid of x that micromanager has
        end
        
        function trig_mode = getTrigMode(obj)
            trig_mode = obj.getProperty('Trigger');
        end

        function binning = getBinning(obj)
            binning = obj.getProperty('Binning');
            binning = str2num(binning);
        end
        
        function Readout_time = getReadoutTime(obj)
            Readout_time = obj.getProperty('ReadoutTime');
            Readout_time = str2num(Readout_time);
        end
        
        %% Settings and Callbacks
        function settings(obj,panelH)
            function_handle=@obj.property_change;
            h=uicontrolgroup(obj.property_cell_array,function_handle,'Parent',panelH);
            obj.panel_handle=h;
        end

    end
end
