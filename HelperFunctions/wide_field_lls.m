% %%
%  ax = subplot(1,2,1)
% img = squeeze(max(imgs2, [], 3));
% imagesc(wl_img.image.image)
% colormap('bone')
% set(ax,'DataAspectRatio',[1 1 1])
% for i=1: length(fres)
%     hold on
%     scatter(realy(i+12*0),realx(i+12*0),30,c(length(fres)+1-i,:),'Linewidth',2)
% end
% hold off
% for i=690:length(xx)
% ax2 = subplot(1,2,2)  
% imagesc(imgs(:,:,i));
% set(ax2,'DataAspectRatio',[1 1 1])
%    title(num2str(i))
%    for i=1: length(fres)
%     hold on
%     scatter(realy(i+12*0),realx(i+12*0),30,c(length(fres)+1-i,:),'Linewidth',0.5)
% end
% hold off
%    waitforbuttonpress
%  end
%%

% d = load('Z:\Experiments\Diamond\EG313_2021Oct\20211029\Experiments_ResonanceEMCCD2021_10_30_21_00_59.mat');
% d = load('Z:\Experiments\Diamond\EG313_2021Oct\20211029\Experiments_ResonanceEMCCD2021_10_30_21_52_19.mat');
% d = load('Z:\Experiments\Diamond\EG313_2021Oct\20211029\Experiments_ResonanceEMCCD2021_10_30_20_42_15.mat');
% d = data;
% d=load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_ResonanceEMCCD2021_11_01_17_07_24.mat')
% d=load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_ResonanceEMCCD2021_11_01_18_10_41.mat')_OD0_cavity
% d=load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_ResonanceEMCCD2021_11_01_19_23_30.mat')_OD0_cavity
% d=load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_ResonanceEMCCD2021_11_01_19_45_01.mat');%OD1_cavity
% 
%
% d = load('Z:\Experiments\Diamond\EG313_2021Nov\Experiments_ResonanceEMCCD2021_11_02_14_46_27.mat')
% d = load('Z:\Experiments\Diamond\EG313_2021Oct\20211029\Experiments_ResonanceEMCCD2021_10_30_21_00_59.mat');
% wl_img=load('Z:\Experiments\Diamond\EG313_2021Nov\Image2021_11_02_15_03_25_wg.mat');
% d=load('Z:\Experiments\Diamond\EG313_1108\Experiments_PLECWAVE2021_11_08_22_04_17.mat');
% wl_img=load('Z:\Experiments\Diamond\EG313_1108\Image2021_11_08_22_10_31.mat');

% d=load('Z:\Experiments\Diamond\EG313_1108\Experiments_PLECWAVE2021_11_09_13_17_51_green8mW.mat');
wl_img=load('Z:\Experiments\Diamond\EG313_1108\Image2021_11_09_13_28_25_wl.mat');

% wl_img=load('Z:\Experiments\Diamond\EG313_2021Nov\Image2021_11_01_15_55_18.mat');
xx = d.data.data.data.freqMeasured;
imgs = d.data.data.data.images_EMCCD;

% for i=1:length(xx)
%     imagesc(imgs(:,:,i));
%     title(num2str(i))
%     waitforbuttonpress
% end
    
    if ~isfield(d, 'imgs2')
        d.imgs2 = imgs;

        for ii = 1:length(xx)
            if ~mod(ii, 10)
                ii;
            end
            d.imgs2(:,:,ii) = flatten(imgaussfilt(remove_spikes(imgs(:,:,ii), 3),1));
        end
        
        return;
    end
    
    imgs2 = d.imgs2(:,:,1:length(xx));

figure(1)
ax2 = subplot(1,2,2)
allpts0 = reshape(imgs2, [512*512, length(xx)]);
allpts0(max(allpts0, [],  2) < 50000, :) = [];
allpts0(min(allpts0, [],  2) > 3000, :) = [];
axis square
p0=zeros(5,length(allpts0(:,1)));
[p0(5,:),p0(3,:)]=find(allpts0==max(allpts0, [],  2));

box('on');

for i = 1:length(allpts0(:,1))
    p0(4,i)=allpts0(p0(5,i),p0(3,i));
    [a,b]=find(d.imgs2(:,:,p0(3,i))==p0(4,i));
    p0(1,i)=a(1);
    p0(2,i)=b(1);
end
a1=1;
fres=unique(p0(3,:));
realx=zeros(1,length(fres));
realy=zeros(1,length(fres));
reali=zeros(1,length(fres));
reala=zeros(1,length(fres));
realf=zeros(1,length(fres));
realpoints=zeros(5,length(fres));
sloc=zeros(1,length(fres));
swid=zeros(1,length(fres));

for i = 1: length(fres)
    pmax=0;
    ptx=[];
    pty=[];
    for j = 1:length(allpts0(:,1))
        if p0(3,j)==fres(i)
            pmax=max(pmax,p0(4,j));
            ptx=[ptx;p0(1,j)];
            pty=[pty;p0(2,j)];
        end
    end
    xi=find(p0(4,:)==pmax)
    xi=xi(1);
%     for k = 1:length(ptx)
%         if (ptx(k)-p0(1,xi))^2+(pty(k)-p0(2,xi))^2<50
%             a1=a1*1;
%         else
%             a1=a1*0;
%         end
%     end
%     a1
    realx(i)=p0(1,xi);
    realy(i)=p0(2,xi);
    reali(i)=p0(5,xi);
    reala(i)=p0(4,xi);
    realf(i)=p0(3,xi);
%     realpoints(i)=p0(:,xi);
end
a1
c=jet(length(fres));
    
yy=allpts0(reali,:);
for i =1:length(fres)
%     a=lorentzfit(xx',yy(i,:)',1,[reala(i) xx(realf(i)) 0.0005 0],[[0*reala(i);1*reala(i)],[min(xx);max(xx)],[3e-5;2e-4],[0;0]]);
%     ss=coeffvalues(a);
%     sloc(i)=(ss(2)-min(xx))*1e3;
%     swid(i)=ss(3);
x=xx;
y=yy(i,:);
pos =xx(realf(i));
bg=min(y);
widthGuess = .000003;

[ fit_type,eq ] = lorentzN( 1,bg );
% fit_type = gaussN(i);
options = fitoptions(fit_type);
freqstep = median(diff(x));

% upper_width = (max(x)-min(x))*ones(1,1);
upper_width = 0.0004*ones(1,1);
lower_width = 0.00003*ones(1,1);
start_width = widthGuess*ones(1,1);
% upper_width = .0001;
% lower_width = freqstep;
% start_width = widthGuess;

upper_amps = 2*max(y)*ones(1,1);
lower_amps = zeros(1,1);
start_amps = .8*(max(y)-min(y))*ones(1,1);

%upper_amps = 2*max(y)*ones(1,i)/(data.data.resonant_time*1e-6);
%lower_amps = zeros(1,i)/(data.data.resonant_time*1e-6);
%start_amps = (max(y)-min(y))*ones(1,i)/(data.data.resonant_time*1e-6);

upper_pos = max(x)*ones(1,1);
lower_pos = min(x)*ones(1,1);
start_pos = pos;

options.Upper = [upper_amps upper_pos upper_width max(y)];
options.Lower = [lower_amps lower_pos lower_width 0     ];
options.Start = [start_amps start_pos start_width median(y)];


[f,~] = fit(x',y',fit_type,options);

fitcoeffs = coeffvalues(f);
samps(i) = fitcoeffs(1);
slocs(i) = fitcoeffs(2);
swids(i) = fitcoeffs(3)*1e6;
end

labels=[];

for i=1: length(fres)
    hold on
    plot((xx-min(xx)*ones(1,length(xx)))*1e3,yy(i+12*0,:),'linewidth',2,'Color',c(length(fres)+1-i,:))
    labels=[labels;strcat({num2str(slocs(i+12*0))},{'THz and '},{num2str(floor(swids(i+12*0)))},{'MHz'})];
end
hold off
title(['(b) PLE with Laser Frequency starts at ' num2str(min(xx)) 'THz'], 'FontName', 'Times New Roman');
ylim([0 1.2*max(max(yy))]);
xlim([0, (max(xx)-min(xx))*1e3])
% ylim([0 1.5e4])
% xlim([0 12])
xlabel('Detuned (GHz)')
ylabel('Intensity(a.u.)')
% yticks([])

set(gca,'FontSize',16,'FontName','Times New Roman')

legend(labels)


ax = subplot(1,2,1)
img = squeeze(max(imgs2, [], 3));
imagesc(wl_img.image.image)
colormap('bone')
% xticks([])
% yticks([])
%     image(ax, hsv2rgb(H, V, V))
for i=1: length(fres)
    hold on
    scatter(realy(i+12*0),realx(i+12*0),30,c(length(fres)+1-i,:),'Linewidth',2)
end
hold off
set(ax,'DataAspectRatio',[1 1 1])
set(gca,'FontSize',16,'FontName','Times New Roman')
title('(a) White Light Image','FontName', 'Times New Roman')
    function img = flatten(img0)
        img = img0 - imgaussfilt(img0, 10);
    end