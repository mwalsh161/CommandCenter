function [ translated ] = Brown_Conrady( a, imPoints )
%BROWN_CONRADY Apply transformation 2nd order in r (only even powers)
%   a = [xp yp T1 T2 R1 R2]

% Define x and y and r
x = imPoints(:,1);  % Nx1
y = imPoints(:,2); % Nx1
r = (x-a(1)).^2 + (y-a(2)).^2;  % Nx1

% Calculate radial distortion
a(3) = a(3)/1e9;
a(4) = a(4)/1e9;
a(5) = a(5)/1e9;
if length(a) == 6 % second order
    a(6) = a(6)/1e18;
    radialX = (1+a(5)*r.^2+a(6)*r.^4).*x;
    radialY = (1+a(5)*r.^2+a(6)*r.^4).*y;
else % first order
    radialX = (1+a(5)*r.^2).*x;
    radialY = (1+a(5)*r.^2).*y;
end

% Calculate tangential distortion
tangentialX = 2*a(3)*x.*y+a(4)*(r.^2+2*x.^2);
tangentialY = a(3)*(r.^2+2*y.^2)+2*a(4)*x.*y;

% Put together
appX = radialX + tangentialX; % Nx1
appY = radialY + tangentialY;

translated = [appX appY];
end

