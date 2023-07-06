function run( obj,status,managers,ax )
% Main run method (callback for CC run button)
obj.abort_request = false;
status.String = 'Experiment started';
drawnow;
% Edit here down (save data to obj.data)
% Tips:
% - If using a loop, it is good practice to call:
%     drawnow; assert(~obj.abort_request,'User aborted.');
%     as frequently as possible
% - try/catch/end statements useful for cleaning up
% - You can get a figure-like object (to create subplots) by:
%     panel = ax.Parent; delete(ax);
%     ax(1) = subplot(1,2,1,'parent',panel);
% - drawnow can be used to update status box message and any plots

% Edit this to include meta data for this experimental run (saved in obj.GetData)
obj.meta.prefs = obj.prefs2struct;
obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
numberImages = obj.numberImages;
% ROI_x = [200:550];
% ROI_y = [400:750];
ROI_x = [200:600];
ROI_y = [300:600];
try
    
    if length(obj.exposureTime) == 1
        obj.imaging.exposure = obj.exposureTime;
        for i = 1:length(obj.emGain)
            obj.imaging.EMgain = obj.emGain(i);
            tic;
            for j = 1:numberImages
                %         obj.greenLaser.power = green;
                assert(~obj.abort_request,'User aborted.');
%                 obj.data.images(:,:,i,j) = obj.imaging.snapImage;
                picture = obj.imaging.snapImage;
                obj.data.images(:,:,i,j) = picture(ROI_x,ROI_y);
                obj.data.timestamp(j) = toc;
%                 pause(20); % pause for 20 s
%                 obj.data.time(j,:) = fix(clock);
                %         figure(1)
                %         imagesc(obj.data.images(:,:,i,j));
            end
        end
    elseif length(obj.emGain) == 1
        obj.imaging.EMgain = obj.emGain;
        for i = 1:length(obj.exposureTime)
            obj.imaging.exposure = obj.exposureTime(i); 
            for j = 1:numberImages
                %         obj.greenLaser.power = green;
                assert(~obj.abort_request,'User aborted.');
%                 obj.data.images(:,:,i,j) = obj.imaging.snapImage;
                picture = obj.imaging.snapImage;
                obj.data.images(:,:,i,j) = picture(ROI_x,ROI_y);
                %obj.data.time(j,i) = fix(clock);
                %         figure(1)
                %         imagesc(obj.data.images(:,:,i,j));
            end
        end
    end
        
    obj.data.exposureTime = obj.exposureTime;
    obj.data.emGain = obj.emGain;
   
catch err
    
end
% CLEAN UP CODE %
if exist('err','var')
    % HANDLE ERROR CODE %
    rethrow(err)
end
end
