function id = Resonance(obj,data,file,parent,data_type,dataID,ax)
%RESONANCE Analysis file for spectrums. Each res should have raw, center, Q and contrast.
%   This is most likely called by obj.Spectrum

im_file = [file(1:end-3) 'png'];
% Create image if necessary
if ~exist(im_file,'file')
    % Plot figure to save image file
    f = figure('visible','off');
    copyobj(ax,f);
    saveas(f,im_file);
    close(f)
end
% Organize necessary data
dat = {im_file,file,data.center,data.Q,data.contrast,data.notes};
% Save and update parent if general
id = obj.add_data(dat,parent,data_type,dataID);

end

