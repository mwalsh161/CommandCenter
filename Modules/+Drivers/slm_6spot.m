kangle= 60*pi/180;
kangle = 93*pi/180;
kstep = 13e-4;
% kstep = 25e-4;
% nspots = 6;
% ki=[kstep*(-1) kstep*(-2) kstep*(-3) kstep*(-4) kstep*(-5) kstep*(-6)];
% %w=1./[1:nspots];
% w=[1 0.45 0.52 0.5 0.45 0.39];
w=[1.7 2 1.1 0.5 0.9 1];
w=[1.5 3 0.3 2.5 2.5 2];
% w=[0 0 1 0 0 0]
nspots = 6;
ki=[kstep*(-1) kstep*(-2) kstep*(0) kstep*(2) kstep*(1) kstep*(-3)];
phi=[0 pi/2 0 pi/2 pi pi];
%w=1./[1:nspots];

%w=[1 0.65 0.52 0.51 0.4 0.5];



% setting the range of sweep in weight to calculate the real matrix
% component
weights = cell(1, nspots);
phis = cell(1, nspots);
images = cell(1, nspots);
indices = cell(1, nspots);
maxes = cell(1, nspots);
masks = zeros(1920,1200,nspots);
fullmask = zeros(1920,1200);
    for j=1:nspots
        k = ki(j);
        slm.blaze(k*cos(kangle),k*sin(kangle),phi(j));
        masks(:,:,j) = slm.blaze(k*cos(kangle),k*sin(kangle),phi(j)); %all 0
        fullmask = fullmask + sqrt(w(j)/sum(w))*exp(1i*masks(:,:,j));
    end
fullmask = angle(fullmask);
slm.load_data(fullmask)
