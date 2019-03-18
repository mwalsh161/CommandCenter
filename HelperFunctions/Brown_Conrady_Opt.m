function F = Brown_Conrady_Opt( a, realPoints, imPoints )
%BROWN_CONRADY_OPT Radial and tangential distortion optimization
%   a(1:7) = a1...a5, xp, yp

appPoints = Brown_Conrady(a,imPoints);

% Get the error
errX = (appPoints(:,1) - realPoints(:,1)).^2;
errY = (appPoints(:,2) - realPoints(:,2)).^2;
F = errX + errY;
end

