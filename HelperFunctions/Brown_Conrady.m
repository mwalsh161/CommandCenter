function [ translated ] = Brown_Conrady( a, imPoints )
%BROWN_CONRADY Apply transformation 2nd order in r (only even powers)
%   a(1:7) = [a1 a2 a4 a5 xp yp]

% Define x and y and r
x = imPoints(:,1);  % Nx1
y = imPoints(:,2); % Nx1
r = (x-a(5)).^2 + (y-a(6)).^2;  % Nx1

% Calculate radial distortion
a(1) = a(1)/1e9;
a(2) = a(2)/1e17;
a(3) = a(3)/1e8;
a(4) = a(4)/1e8;

radialX = (1+a(1)*r.^2+a(2)*r.^4).*x;
radialY = (1+a(1)*r.^2+a(2)*r.^4).*y;
%radialX = (1+a(1)*r.^2).*x;
%radialY = (1+a(1)*r.^2).*y;

% Calculate tangential distortion
tangentialX = 2*a(3)*x.*y+a(4)*(r.^2+2*x.^2);
tangentialY = a(3)*(r.^2+2*y.^2)+2*a(4)*x.*y;

% Put together
appX = radialX + tangentialX; % Nx1
appY = radialY + tangentialY;

translated = [appX appY];
end

