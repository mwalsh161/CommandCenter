function F = RotationScaleTranslation_Opt( a, realPoints, imPoints )
%ROTATIONSCALETRANSLATION Apply transformation
%   a(1:4) = [scaling xOffset yOffset theta]
%   xOffset and yOffset are applied first.

appPoints = RotationScaleTranslation(a,imPoints);

% Get the error
errX = (appPoints(:,1) - realPoints(:,1)).^2;
errY = (appPoints(:,2) - realPoints(:,2)).^2;
F = errX + errY;
end

