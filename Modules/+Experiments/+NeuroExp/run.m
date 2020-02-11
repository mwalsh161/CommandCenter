function run(obj,statusH,managers,ax)
%% set this experiments settings to OMDR
try
    message = [];
    modules = managers.Sources.modules;
    obj.data = [];
    obj.abort_request = false;
    obj.firstRun = true;
    %% initilize Camera
    assert(~obj.abort_request,'User aborted');
    obj.camera = managers.Imaging.active_module.instance;
    obj.camera.reset;
    [width,height] = obj.camera.getImageDimension;
    obj.camera.exposure = obj.exposureTime;
    
    %% initialize laser
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    
    %% initialize data matrix
    assert(~obj.abort_request,'User aborted');
    numSaves = ceil(obj.numImages/obj.saveImageNum);
    currFram = 0;
  
    %% run ODMR experiment
    for currExp = 1:numSaves
        if  currExp == numSaves
            numImages = mod(obj.numImages,obj.saveImageNum*(currExp-1));
            if numImages == 0
                numImages = obj.saveImageNum;
            end
        else
            numImages = obj.saveImageNum;
        end
        obj.data.raw_data = NaN(width,height,numImages);
        for imageNum = 1:numImages
            assert(~obj.abort_request,'User aborted');
            currFram = currFram + 1;
            dat_image = [];
            obj.laser.on;
            dat_image = obj.camera.snap;
            obj.laser.off;
            obj.data.raw_data(:,:,imageNum) = dat_image;
            pause(obj.waitTime)
            %% plot image
            imagesc(obj.data.raw_data(:,:,imageNum),'parent',ax);
            axis image
            axis xy
            colorbar(ax)
            axis(ax,'image');
            drawnow
            title(sprintf('Image %d of %d',currFram,obj.numImages),'parent',ax)
        end
        if ~(currExp == numSaves)
            notify(obj,'save_request'); %save data to conserve memory
            data.data.raw_data = NaN(width,height,obj.saveImageNum);
            pause(1)
            obj.firstRun = false;
        end
    end
catch message
    
end
%% cleanup

obj.laser.off;

%%
if ~isempty(message)
    rethrow(message)
end

end