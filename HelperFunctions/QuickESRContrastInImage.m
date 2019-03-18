function [Contrast, nOfPoints] = QuickESRContrastInImage(data_img,norm_img)
% function quickly finds the brightest XX number of pixels and uses them to
% find the ESR contrast.

[mImage, nImage] = size(norm_img);
data_img_1d = zeros(1,mImage*nImage);
data_img_1d(:) = norm_img;

[~, Pixel_ind_descend] = sort(data_img_1d, 'descend');

nOfPoints = round(mImage*nImage*0.1); % pick the XX highest pixels points;

Contrast = mean(data_img(Pixel_ind_descend(1:nOfPoints))./norm_img(Pixel_ind_descend(1:nOfPoints)));
end
