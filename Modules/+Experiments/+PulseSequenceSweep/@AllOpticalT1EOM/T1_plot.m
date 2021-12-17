%%
expH = Experiments.PulseSequenceSweep.AllOpticalT1EOM.instance
expseq = expH.BuildPulseSequence(1)
expseq.draw

%%
bin1=data.data.data.sumCounts(:,:,1);
bin2=data.data.data.sumCounts(:,:,2);
bin3=data.data.data.sumCounts(:,:,3);
bin4=data.data.data.sumCounts(:,:,4);

h3=histogram(bin3);
h3y=h3.Values;
h3x=h3.BinEdges-0.5;
h3x=h3x(h3x>=0);
h2=histogram(bin2);
h2y=h2.Values;
h2x=h2.BinEdges-0.5;
h2x=h2x(h2x>=0);
h4=histogram(bin4);
h4y=h4.Values;
h4x=h4.BinEdges-0.5;
h4x=h4x(h4x>=0);
h1=histogram(bin1);
h1y=h1.Values;
h1x=h1.BinEdges-0.5;
h1x=h1x(h1x>=0);

figure(1); 
plot(h3x,h3y/sum(h3y),'r')
hold on
plot(h2x,h2y/sum(h2y),'k')
% plot(h1x,h1y/sum(h1y),'b')
% plot(h4x,h4y/sum(h4y),'g')
hold off
xlabel('Count read')
ylabel('Probability')
legend('bright','dark')
set(gca,'Fontsize',18)
title('Single shot readout histogram')



%%
% x0=0:100:1000;
x0=[0 1];
bin1avg=mean(bin1);
bin2avg=mean(bin2);
bin3avg=mean(bin3);
bin4avg=mean(bin4);
figure(1)
plot(x0,bin1avg,'b')
hold on
plot(x0,bin2avg,'k')
plot(x0,bin3avg,'r')
plot(x0,bin4avg,'g')
hold off
xlabel('delay(us)')
ylabel('Counts')
legend('Ci1','Ci2','Cr1','Cr2')
title('Sample 400, avereage 100')
set(gca,'FontSize',18)
%%
figure(2)
y0=bin3avg./bin2avg;
plot(x0,y0)

xlabel('delay(us)')
ylabel('Cr1/Ci2')
set(gca,'FontSize',18)
