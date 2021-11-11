% d=load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_PulseSequenceSweep_AllOpticalT1emccd2021_11_06_20_59_32.mat');
% figure(1)
s=length(data.data.data.images_EMCCD(1,1,:));
% for i=1:s
% %     imagesc(data.data.data.images_EMCCD(188-50:198+50,300-50:312+50,i));
%     imagesc(data.data.data.images_EMCCD(:,:,i));
%     title(num2str(data.data.meta.vars.vals(i)))
%     waitforbuttonpress;
% end
figure(2)
xx = eval(data.data.meta.prefs.tauTimes_us);
a=squeeze((data.data.data.images_EMCCD(233,410,:)));%./(sum(sum(data.data.data.images_EMCCD(:,:,:))));
b=squeeze((data.data.data.images_EMCCD(191,400,:)));

plot(xx,squeeze(a));
hold on
plot(xx,squeeze(b));
xlabel('t(us)')