function id = Confocal(obj,data,file,parent,data_type,dataID,ax)
xmin = data.ROI(1,1);
xmax = data.ROI(1,2);
ymin = data.ROI(2,1);
ymax = data.ROI(2,2);
% Plot figure to save image file
f = figure('visible','off');
newAx = axes('parent',f,'xlim',get(ax,'xlim'),...
             'ylim',get(ax,'ylim'),'clim',get(ax,'clim'));
imagesc([xmin xmax],[ymin ymax],data.image,'parent',newAx)
colormap(newAx,colormap(ax));
colorbar(newAx)
im_file = [file(1:end-3) 'png'];
saveas(f,im_file);
close(f)
% Organize necessary data
dat = {im_file,file,xmin,xmax,ymin,ymax,obj.laser_power,data.notes};
% Save and update parent if general
id = obj.add_data(dat,parent,data_type,dataID);
end