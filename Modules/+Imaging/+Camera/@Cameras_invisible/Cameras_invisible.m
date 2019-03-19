classdef Cameras_invisible <  Modules.Imaging 
    
    properties
        exposure % in milliseconds
        binning  % set binning
        focusThresh = 0;
        maxROI
    end
    
    properties(Abstract)
        CamCenterCoord
    end
    
    properties(Constant,Abstract)
        dev              %device name, for instance Andor
    end
    
    %% set properties so that we are backwards compatable. These set methods call relevant methods
    methods
        function set.exposure(obj,val)
            obj.setExposure(val)
            obj.exposure = obj.getExposure;
        end
        
        function set.binning(obj,val)
            obj.setBinning(val)
            obj.binning = obj.getBinning;
        end
        
        function exposure = get.exposure(obj)
            exposure = obj.getExposure;
        end
        
        function binning = get.binning(obj)
            binning = obj.getBinning;
        end
    end
    
    methods
        %% these are the abstract methods described in the Imaging Module.
        function metric = focus(obj,ax,Managers)
            %this method should bring your sample into focus.
            
            error ('Not Implemented!')
        end
        
        function startVideo(obj,hImage)
            % this method begins continually taking images (i.e a video) and updating
            % them to hImage
            
            error ('Not Implemented!')
        end
        
        function stopVideo(obj)
            %this method should stop the video.
            
            error ('Not Implemented!')
        end
        
        function dat = snap(obj,varargin)
            %this method takes an image from the camera no matter what trigger mode
            %the camera is in. dat should be an n x m matrix. Should error if buffer is empty.
            %if an image axis is given snap should plot to it.
            error ('Not Implemented!')
        end
        
    end
    methods
        function reset(obj)
            %this method should reset the camera. Default settings should
            %be internal trigger and an exposure time of 30 ms. Camera
            %should be in Internal mode. Should accept an optional input to set binning. 
            %Camera should be able to call snap and return an image afterward.
            
            error ('Not Implemented!')
        end
        function startSequenceAcquisition(obj,Num_images)
            %this method prepares the camera to begin a triggered sequence
            %of exposures. Expect the state of the camera to be that returned by reset.
            %It should take in as in input Num_images which
            %is the total number of triggers. Exposure time should be set
            %by the time that the IO trigger line is high.
            
            error ('Not Implemented!')
        end
        function dat_matrix = stopSequenceAcquisition(obj,Num_images)
            %this method should be called after a series of triggered
            %exposures. It should return a dat_matrix where dat_matrix is
            %an n x m x Num_images image stack. Where Num_images is an input stating how many images you expect.
            %It should call reset afterwards to return the camera to a known state.
            
            error ('Not Implemented!')
        end
        %% set methods
        
        % exposure, gain and trig mode are seperated to make clear that
        % your camera must have these properties 
        
        function setExposure(obj,Exposure)
            %this method sets the exposure of the camera. Exposure time
            %should be in units of milliseconds and have a data type of double.
            
            error ('Not Implemented!')
        end
        
        function setEMGain(obj,Gain)
            %this method sets the EM gain of the camera if applicable. A Gain of zero
            %should turn off EM switch.Gain should have a data type of
            %double. If your camera does not support EM gain should throw a
            %warning.
            
            error ('Not Implemented!')
        end
        
        function setGain(obj,Gain)
            %this method sets the gain of the camera if applicable. 
            %Gain should have a data type of double. If your camera does 
            %not support gain should throw a warning.
            
            error ('Not Implemented!')
        end
        
        function setTrigMode(obj,trig_mode)
            %this methods sets the trigger mode of the camera. Should accept (at least) 2 inputs:
            %1.) <Internal>-->this means that the camera uses an exposure time
            %defined by its <internal> clock.
            %2.) <External Exposure>--> this means that the camera uses an
            %exposure time defined by an external clock. Such as the
            %pulseblaster. Camera should expose for the time the trigger IO
            %line is high.
            
            error ('Not Implemented!')
        end
        
        function setBinning(obj,binning)
           %this methods sets the binning for the camera. Binning should be
           %a double. Binning options: 1,2,4,8
            
            error ('Not Implemented!')  
        end
        %% get methods
        
        function Exposure = getExposure(obj)
            %this method gets camera's exposure. Exposure should be a
            %double.
            
            error ('Not Implemented!')
        end
        
        function Gain = getEMGain(obj)
            %this method gets camera's EM_gain. An EM gain of zero should
            %mean the EM switch is off. If your camera does 
            %not support get_EM_gain return [].
            
            error ('Not Implemented!')
        end
        
        function Gain = getGain(obj)
            %this method gets the gain of the camera if applicable. 
            %Gain should have a data type of double. If your camera does 
            %not support get_gain should return [].
            
            error ('Not Implemented!')
        end
        
        function trig_mode = getTrigMode(obj)
            %this method gets camera's trig_mode.
            
            error ('Not Implemented!')
        end
        
        function binning = getBinning(obj)
           %this methods gets the binning for the camera. Binning should be
           %a double.
            
            error ('Not Implemented!')  
        end
        
        function Readout_time = getReadoutTime(obj)
            %this method gets camera's Readout_time.This is the minimum
            %time needed between triggered images for the camera not to
            %miss a trigger. Should be in units of milliseconds.
            
            error ('Not Implemented!')
        end
    end
end