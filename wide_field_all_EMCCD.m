% d =load('Z:\Experiments\Diamond\EG309 Cavity\03082022_angle_magnet\Experiments_ResonanceEMCCDonly2022_03_08_20_20_55_pillar_widefield.mat');
% d = load('Z:\Experiments\Diamond\EG309 Cavity\03082022_angle_magnet\Experiments_ResonanceEMCCDonly2022_03_09_15_05_14_cavity_widefield.mat');
% xx = d.data.data.data.freqMeasured;
xx = 484.12246:(484.15088-484.12246)/500:484.15088;
wl = load('Z:\Experiments\Diamond\EG309 Cavity\03082022_angle_magnet\Image2022_03_09_15_21_17_wl.mat');
imgs = d.data.data.data.images_EMCCD;
%%
% figure(2)
% for i=1:length(xx)
%     imagesc(imgs(:,:,i));
%     title(strcat(num2str(i),';',num2str(xx(i))));
%     waitforbuttonpress
% end
%%
% Emitter filter
mincount=6000; %filter emitter
rxmin=100;
rymin=220;
rxmax=275;
rymax=305;

%display
xlim_min=150;
xlim_max=400;
ylim_min=50;
ylim_max=310;
% 
% for i=1:length(xx)
%     colormap('bone')
%     imagesc(imgs(:,:,i));
%     tt=strcat(num2str(i),' Freq:',num2str(d.data.data.data.freqMeasured(i),'%4.6f'),'THz; Voltage:',num2str(100*(i-1)/(length(xx)-1)),'V');
%     title(tt);   
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
% ax2 = subplot(1,2,2)
allpts0 = reshape(imgs2, [512*512, length(xx)]);
allpts0(max(allpts0, [],  2) < mincount, :) = [];
% allpts0(max(allpts0, [],  2) > 64000, :) = [];
% allpts0(min(allpts0, [],  2) > 2000, :) = [];
% axis square
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
    xi=find(p0(4,:)==pmax);
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
a1;
c=jet(length(fres));
    
yy=allpts0(reali,:);

labels=[];

% rxmin=140;
% rymin=280;
% rxmax=250;
% rymax=350;
% 
% rxmin=100;
% rymin=100;
% rxmax=250;
% rymax=350;
% 
% rxmin=100;
% rymin=200;
% rxmax=270;
% rymax=320;

% rxmin=50;
% rymin=300;
% rxmax=200;
% rymax=350;

% rxmin=160;
% rymin=320;
% rxmax=200;
% rymax=340;

% rxmin=100;
% rymin=100;
% rxmax=500;
% rymax=500;
% 
% 
% rxmin=225;
% rymin=150;
% rxmax=300;
% rymax=300;
%%

wgc=[];
wgw=[];
wgx=[];
wgy=[];
wgpx=[];
wgpy=[];
wgym=[];
for i=1: length(fres)
    hold on
    if (realx(i)<rxmax) & (realx(i)>rxmin) & (realy(i)<rymax) & (realy(i)>rymin) 
        wgt=yy(i,:);
        [wgtv,wgtp]=find(wgt==max(wgt));
%         wgt(wgtp)=min(wgt);
%         wgt(wgtp-1)=min(wgt);
        wgt(max(1,wgtp-2):min(length(yy),wgtp+2))=min(wgt);
%         wgt(wgtp+2)=min(wgt);
%         wgt(wgtp+1)=min(wgt);
        if max(wgt(max(1,wgtp-floor(length(wgt)/20)):min(length(wgt),wgtp+floor(length(wgt)/20))))>0.5*max(yy(i,:))
%         plot((xx-min(xx)*ones(1,length(xx)))*1e3,yy(i+12*0,:),'linewidth',2,'Color',c(length(fres)+1-i,:))
%         labels=[labels;strcat({num2str(slocs(i+12*0))},{'THz and '},{num2str(floor(swids(i+12*0)))},{'MHz'})];
%             x=xx;
%             y=yy(i,:);
%             pos =xx(realf(i));
%             bg=min(y);
%             widthGuess = .000003;
% 
%             [ fit_type,eq ] = lorentzN( 1,bg );
%             % fit_type = gaussN(i);
%             options = fitoptions(fit_type);
%             freqstep = median(diff(x));
% 
%             % upper_width = (max(x)-min(x))*ones(1,1);
%             upper_width = 0.0004*ones(1,1);
%             lower_width = 0.00003*ones(1,1);
%             start_width = widthGuess*ones(1,1);
%             % upper_width = .0001;
%             % lower_width = freqstep;
%             % start_width = widthGuess;
% 
%             upper_amps = 2*max(y)*ones(1,1);
%             lower_amps = zeros(1,1);
%             start_amps = .8*(max(y)-min(y))*ones(1,1);
% 
%             %upper_amps = 2*max(y)*ones(1,i)/(data.data.resonant_time*1e-6);
%             %lower_amps = zeros(1,i)/(data.data.resonant_time*1e-6);
%             %start_amps = (max(y)-min(y))*ones(1,i)/(data.data.resonant_time*1e-6);
% 
%             upper_pos = max(x)*ones(1,1);
%             lower_pos = min(x)*ones(1,1);
%             start_pos = pos;
% 
%             options.Upper = [upper_amps upper_pos upper_width max(y)];
%             options.Lower = [lower_amps lower_pos lower_width 0     ];
%             options.Start = [start_amps start_pos start_width median(y)];
% 
% 
%             [f,~] = fit(x',y',fit_type,options);
% 
%             fitcoeffs = coeffvalues(f);
%             samps(i) = fitcoeffs(1);
%             slocs(i) = fitcoeffs(2);
%             swids(i) = fitcoeffs(3)*1e6;

            wgc=[wgc;xx(wgtp)];
%             wgw=[wgw;swids(i)];
            wgx=[wgx;(xx-min(xx)*ones(1,length(xx)))*1e3];
            wgy=[wgy;yy(i,:)];
            wgym=[wgym;max(yy(i,:))];
            wgpx=[wgpx;realy(i)];
            wgpy=[wgpy;realx(i)];
        end
        
    end
    
end

% c=jet(length(wgpx));

markerlist=['o';'+';'x';'s';'d';'^';'v';'>';'<';'p';'h';'*';'_';'|'];
markerlist2=['-o';'-+';'-x';'-s';'-d';'-^';'-v';'->';'-<';'-p';'-h';'-*';];
c=[1 0 0;1 0.5 0;1 1 0; 0.5 1 0; 0 1 0; 0 1 1;0 0.5 1; 0 0 1; 0.5 0 1; 1 0 1];
if length(wgpx)<40
   
end

if length(wgpx)>=40
     s2 = subplot(1,4,2)
     for i=1:39
        hold on
        plot(wgx(i,:)-wgx(i,find(wgy(i,:)==max(wgy(i,:))))*ones(1,length(wgx(i,:))),i+wgy(i,:)/max(wgy(i,:)),markerlist2(1+floor(i/10)),'linewidth',2,'Color',c(1+(i-floor(i/10)*10),:))
    %     labels=[labels;strcat(num2str(i),':',{num2str((data.FOV.wgc(i)+0*(data.FOV.wgc(i)-484)*10000))},{'THz & '},{num2str(floor(data.FOV.wgw(i)))},{'MHz'})];
    %     t1=text(data.FOV.wgx(i,find(data.FOV.wgy(i,:)==max(data.FOV.wgy(i,:))))-0.34,1.05*max(data.FOV.wgy(i,:)),num2str(i),'FontSize', 13, 'FontWeight', 'bold');
    %     set(t1,'Color',[0 0 0]);
    end

    hold off
    box on
    ylim([0 40])
    xlim([-1.6 1.6])
    yticks([0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]);
    yticklabels({'0' 'o' '10' '+' '20' 'x' '30' 's' '40' 'd' '50' '^' '60' 'v' '70' '>' '80' '<' '90' 'p' '100'});

    xlabel('Detuned (GHz)')
    ylabel('Emitter number')
    % yticks([])

    set(gca,'FontSize',16,'FontName','Times New Roman')
    s4 = subplot(1,4,4)
    for i=40:length(wgpx)
        hold on
        plot(wgx(i,:)-wgx(i,find(wgy(i,:)==max(wgy(i,:))))*ones(1,length(wgx(i,:))),i+wgy(i,:)/max(wgy(i,:)),markerlist2(1+floor(i/10)),'linewidth',2,'Color',c(1+(i-floor(i/10)*10),:))
    %     labels=[labels;strcat(num2str(i),':',{num2str((data.FOV.wgc(i)+0*(data.FOV.wgc(i)-484)*10000))},{'THz & '},{num2str(floor(data.FOV.wgw(i)))},{'MHz'})];
    %     t1=text(data.FOV.wgx(i,find(data.FOV.wgy(i,:)==max(data.FOV.wgy(i,:))))-0.34,1.05*max(data.FOV.wgy(i,:)),num2str(i),'FontSize', 13, 'FontWeight', 'bold');
    %     set(t1,'Color',[0 0 0]);
    end

    hold off
    box on
    ylim([40 length(wgpx)])
    xlim([-1.6 1.6])
    yticks([0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]);
    yticklabels({'0' 'o' '10' '+' '20' 'x' '30' 's' '40' 'd' '50' '^' '60' 'v' '70' '>' '80' '<' '90' 'p' '100'});

    xlabel('Detuned (GHz)')
%     ylabel('Emitter number')
    % yticks([])

    set(gca,'FontSize',16,'FontName','Times New Roman')
else
     s2 = subplot(1,4,2)
     for i=1:length(wgpx)
        hold on
        plot(wgx(i,:)-wgx(i,find(wgy(i,:)==max(wgy(i,:))))*ones(1,length(wgx(i,:))),i+wgy(i,:)/max(wgy(i,:)),markerlist2(1+floor(i/10)),'linewidth',2,'Color',c(1+(i-floor(i/10)*10),:))
    %     labels=[labels;strcat(num2str(i),':',{num2str((data.FOV.wgc(i)+0*(data.FOV.wgc(i)-484)*10000))},{'THz & '},{num2str(floor(data.FOV.wgw(i)))},{'MHz'})];
    %     t1=text(data.FOV.wgx(i,find(data.FOV.wgy(i,:)==max(data.FOV.wgy(i,:))))-0.34,1.05*max(data.FOV.wgy(i,:)),num2str(i),'FontSize', 13, 'FontWeight', 'bold');
    %     set(t1,'Color',[0 0 0]);
    end

    hold off
    box on
    ylim([0 length(wgpx)])
    xlim([-1.6 1.6])
    yticks([0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]);
    yticklabels({'0' 'o' '10' '+' '20' 'x' '30' 's' '40' 'd' '50' '^' '60' 'v' '70' '>' '80' '<' '90' 'p' '100'});

    xlabel('Detuned (GHz)')
    ylabel('Emitter number')
    % yticks([])

    set(gca,'FontSize',16,'FontName','Times New Roman')
    
end


% legend(labels)
%%

s1 = subplot(1,4,1)
img = squeeze(max(imgs2, [], 3));
% imagesc(d.data.data.data.images_EMCCD(rxmin:rxmax,rymin:rymax,2))
imagesc(wl.image.image(:,:))
% imagesc(imgs(:,:,28))
colormap('bone')
% xticks([])
% yticks([])
%     image(ax, hsv2rgb(H, V, V))
% for i=1: length(fres)
%     hold on
%     if (realx(i)<rxmax) & (realx(i)>rxmin) & (realy(i)<rymax) & (realy(i)>rymin) 
%         scatter(realy(i+12*0),realx(i+12*0),30,c(length(fres)+1-i,:),'Linewidth',2)
%     end
% end

for i=1: length(wgpx)
    hold on
%     if (realx(i)<rxmax) & (realx(i)>rxmin) & (realy(i)<rymax) & (realy(i)>rymin) 
%         scatter(wgpx(i),wgpy(i),30, c(1+(i-floor(i/10)*10),:),markerlist(1+floor(i/10)),'Linewidth',2)
        scatter(wgpx(i),wgpy(i),30,c(1+(i-floor(i/10)*10),:),markerlist(1+floor(i/10)),'Linewidth',2)
%     end
end

scatter(rymin,rxmin,'w','filled')
scatter(rymax,rxmax,'w','filled','s')


hold off
% set(s1,'DataAspectRatio',[1 1 1])
% xticks([0 100 200 300 400])
% yticks([0 100 200 300 400])
% xlabel('y')
% ylabel('x')

xlim([xlim_min xlim_max])
ylim([ylim_min ylim_max])
xticks([])
yticks([])
set(gca,'FontSize',16,'FontName','Times New Roman')

% title('(a) Emitter overlaid image','FontName', 'Times New Roman')
%     function img = flatten(img0)
%         img = img0 - imgaussfilt(img0, 10);
%     end
%%
s3 = subplot(1,4,3)

for i=1:length(wgpx)
    hold on
    scatter(wgc(i),wgym(i),30, c(1+(i-floor(i/10)*10),:),markerlist(1+floor(i/10)),'Linewidth',2)
%     labels=[labels;strcat(num2str(i),':',{num2str((data.FOV.wgc(i)+0*(data.FOV.wgc(i)-484)*10000))},{'THz & '},{num2str(floor(data.FOV.wgw(i)))},{'MHz'})];
%     t1=text(data.FOV.wgx(i,find(data.FOV.wgy(i,:)==max(data.FOV.wgy(i,:))))-0.34,1.05*max(data.FOV.wgy(i,:)),num2str(i),'FontSize', 13, 'FontWeight', 'bold');
%     set(t1,'Color',[0 0 0]);
    if (i/10-floor(i/10))==0
        line([wgc(i) wgc(i)],[mincount 6.5e4],'Color','k','LineStyle','--')
    end
end
set(gca,'FontSize',16,'FontName','Times New Roman')
xlabel('Frequency (THz)')
ylabel('Pixel count')
box on
title('EMCCD Gain:1200, Expose Time:500ms, Pixel:16um*16um')
yticks([3e4, 6e4]);
ylim([mincount 6.5e4]);
hold off


set(s3, 'Position', [0.05 0.1 0.6 0.15])
set(s2, 'Position', [0.7 0.1 0.12 0.85])

% set(s1, 'Position', [0.08 0.38 0.58 0.58])
set(s1, 'Position', [0.05 0.35 0.6 0.6])

if length(wgpy)>=40
    set(s4, 'Position', [0.85 0.1 0.12 0.85])
    set(s2, 'Position', [0.7 0.1 0.12 0.85])
else
    set(s2, 'Position', [0.7 0.1 0.2 0.85])
end

set(gcf,'position',[10,10,1200,800])


% figure(3)
% scatter(wgc,wgw)
% wg6c=wgc;
% wg6w=wgw;

%%
% figure()
% scatter(wg1c,wg1w,'r','filled')
% hold on
% scatter(wg2c,wg2w,'r','filled')
% scatter(wg3c,wg3w,'r','filled')
% scatter(wg4c,wg4w,'r','filled')
% scatter(wg5c,wg5w,'r','filled')
% scatter(wg6c,wg6w,'r','filled')
% hold off
% xlabel('Center frequency(THz)')
% ylabel('Linewidth (MHz)')
% ylim([0 200])
% set(gca,'FontSize',16,'FontName','Times New Roman')

%%
% FOV.wgc=wgc;
% FOV.wgw=wgw;
% FOV.wgx=wgx;
% FOV.wgy=wgy;
% FOV.wgpx=wgpx;
% FOV.wgpy=wgpy;
% FOV.wl=wl_img;
% FOV.pl=pl_img;
% FOV.ROI=[rxmin rxmax;rymin rymax];
% FOV.title='wg31_single_cavity_2';
% save('wg31.mat','FOV')

% a.
