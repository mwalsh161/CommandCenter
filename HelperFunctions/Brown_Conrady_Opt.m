function errs = Brown_Conrady_Opt( a, realPoints, imPoints, scalar )
%BROWN_CONRADY_OPT Radial and tangential distortion optimization
%   a(1:7) = a1...a5, xp, yp
%   output is a metric of "how" grid like it is for each item in the points
%   cell arrays.
%   If scalar is true (default false), the mean of all errs is taken instead
if nargin < 4
    scalar = false;
end

errs = NaN(0,1);
for ind = 1:length(realPoints)
    appPoints = Brown_Conrady(a,imPoints{ind});

    % Optimize perfect grid again
     tform = fitgeotrans(realPoints{ind}, appPoints, 'similarity');
     realPointsT = tform.transformPointsForward(realPoints{ind});
    

    % Get the error
    errX = (appPoints(:,1) - realPointsT(:,1)).^2;
    errY = (appPoints(:,2) - realPointsT(:,2)).^2;
    F = errX + errY;
    
    errs = [errs; F];
end
if scalar
    errs = mean(errs);
end

end

