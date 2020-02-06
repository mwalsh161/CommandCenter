function [ image ] = AcquireImage(h_cam, roi_struct)
%SIMPLE ACQUIRE SINGLE IMAGE WITH 1000MS EXPOSURE TIME
%   Detailed explanation goes here

roi_struct

% if pvcamgetvalue(h_cam, 'PARAM_METADATA_ENABLED')
    exptime = 1000;
    ni = 1;
    image_stream = pvcamacq(h_cam, ni, roi_struct, exptime, 'timed');
    disp([datestr(datetime('now')) ' picture acquired']);
%     image = image_stream(41:end);
    %meta  = image_stream(1:40);
    w = (roi_struct.s2 - roi_struct.s1+1)/roi_struct.sbin;
    h = (roi_struct.p2 - roi_struct.p1+1)/roi_struct.pbin;
    image = reshape(image_stream, [w, h, ni]);
    mean(mean(image))
% else
%     disp('Metadata not enabled!')
% end
end
