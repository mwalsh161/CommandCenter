function [ translated ] = RotationScaleTranslation( a, imPoints )
%ROTATIONSCALETRANSLATION Apply transformation
%   a(1:4) = [scaling xOffset yOffset theta]
%   xOffset and yOffset are applied first.

% Offset
imPoints(:,1) = imPoints(:,1) - a(2);
imPoints(:,2) = imPoints(:,2) - a(3);

x = (imPoints(:,1)*cos(a(4))-imPoints(:,2)*sin(a(4)))*a(1);  % Nx1
y = (imPoints(:,1)*sin(a(4))+imPoints(:,2)*cos(a(4)))*a(1); % Nx1
translated = [x y]; % Nx2
end

