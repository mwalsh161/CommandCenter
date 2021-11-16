% SLM input
w=[1 0.65 0.65 0.55 0.48 0.33];

kangle = 60*pi/180;
kangle = 93*pi/180;
kstep = 17e-4;
% kstep = 25e-4;
% nspots = 6;
% ki=[kstep*(-1) kstep*(-2) kstep*(-3) kstep*(-4) kstep*(-5) kstep*(-6)];
% %w=1./[1:nspots];
% w=[1 0.45 0.52 0.5 0.45 0.39];
w=[1 0.65 0.65 0.55 0.48 0.33];
nspots = 6;
ki=[kstep*(-1) kstep*(-2) kstep*(3) kstep*(2) kstep*(1) kstep*(-3)];
%w=1./[1:nspots];

%w=[1 0.65 0.52 0.51 0.4 0.5];

for i=1:nspots
    
    k = ki(i);
    mask1 = slm.blaze(k*cos(kangle),k*sin(kangle),0); %all 0
    if i==1
        mask = mask1;
    else
        mask = slm.sum_mask_weighted(mask,mask1,w(i));
    end
end
csvwrite('6spot.csv',mask')
% slm.load_data(mask)
%%
camera1 = Imaging.Thorlabs.uc480.instance;
camera1.exposure=20;
images_camera=camera1.snapImage();
figure(1)
plot((images_camera(200:700,507)));
[pks,locs]=findpeaks((images_camera(200:700,507)));
location=locs(find(pks>50));
p1=images_camera(120,507);
p2=images_camera(170,507);
p3=images_camera(219,507);
p4=images_camera(268,507);
p5=images_camera(318,507);
p6=images_camera(367,507);
pn=[p1 p2 p3 p4 p5 p6];
std(pn)

