G = @(x,f)exp(-x.^2/(2*f^2))/(f*sqrt(2*pi));
L = @(x,f)f./(pi*(x.^2+f^2));
f = @(fg,fl)(fg^5+2.69269*fg^4*fl+2.42843*fg^3*fl^2+4.47163*fg^2*fl^3+0.07842*fg*fl^4+fl^5)^(1/5);
eta = @(fg,fl)1.36603*(fl/f(fg,fl))-0.47719*(fl/f(fg,fl))^2+0.11116*(fl/f(fg,fl))^3;
V = @(x,fg,fl)eta(fg,fl)*L(x,f(fg,fl))+(1-eta(fg,fl))*G(x,f(fg,fl));
Vnorm = @(x,fg,fl)(pi*f(fg,fl)*sqrt(2))/(eta(fg,fl)*(sqrt(2)-sqrt(pi))+sqrt(pi))*V(x,fg,fl);
x = -10:0.001:10;

fg = 1;
fl = 0.5;

y = voigt(x, 1, 0, fl, fg);

% figure;
% plot(x,Vnorm(x,fg,fl))
% hold on;
% plot(x,y)
% hold off;
fprintf('My FHWM\n')
FWHM(x,Vnorm(x,fg,fl))
fprintf('Ian''s FHWM\n')
FWHM(x,y)
fprintf('Numerical FHWM\n')
0.5346*fl+sqrt(0.2166*fl^2+fg^2)
fprintf('Exact (?) FHWM\n')
f(fg,fl)

function wid = FWHM(x,y)
    [M,I] = max(y);
    [~,Lm] = min(abs(y(1:I)-M/2));
    [~,Rm] = min(abs(y(I:end)-M/2));
    Rm = Rm+I-1;
    wid = x(Rm) - x(Lm);
end