function spect_id = Spectrum(obj,data,file,parent,data_type,dataID,ax)
%If data has a field called analysis and has analysis.data_name be a valid
% data type, it will save an attachment to the spectrum for each cell
% array in the field analysis.  See Resonance to structure of analysis.
pos = data.position;
x = pos(1);
if isnan(x)
    x = 0;
end
y = pos(2);
if isnan(y)
    y = 0;
end
% Plot figure to save image file
f = figure('visible','off');
newAx = axes('parent',f,'xlim',get(ax,'xlim'),...
             'ylim',get(ax,'ylim'),'clim',get(ax,'clim'));
plot(data.wavelength,data.intensity,'parent',newAx)
s = get(ax,'xlabel');
xlabel(newAx,s.String)
s = get(ax,'ylabel');
ylabel(newAx,s.String)
s = get(ax,'title');
title(newAx,s.String)
im_file = [file(1:end-3) 'png'];
saveas(f,im_file);
close(f)
% Organize necessary data
dat = {im_file,file,x,y,obj.laser_power,data.notes};
% Save and update parent if general
spect_id = obj.add_data(dat,parent,data_type,dataID);
tempID = str2double(spect_id);
if isfield(data,'analysis')&&~isempty(tempID)&&~isnan(tempID)
    for i = 1:numel(data.analysis)
        res = data.analysis{i};
        [~,file,~] = fileparts(file);
        obj.AutoSave.SaveExp(res,ax,[file '_analysis.mat'])
        file = obj.AutoSave.last_exp_fname;
        obj.Save(res,tempID,file,ax)
    end
end
end
