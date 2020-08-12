function quickFastAnalysis(d)
    data = d.data.data.data;
    
    N = 3;
    M = 2;
    
    ii = 8;
    jj = 19;
    
    figure
%     plot(data.Vwl, data.freqs_measured')
    
    imgs = data.images(:,:,:,:,1);
    
    subplot(N,M,1)
    imagesc(max(max(imgs,[],4),[],3))
    hold on 
    scatter(jj, ii);
    subplot(N,M,2)
    imagesc(mean(mean(imgs,4),3))
    hold on 
    scatter(jj, ii);
    
    single = squeeze(imgs(ii,jj,:,:));
    
    subplot(N,M,3)
    imagesc(data.freqs_measured(1:length(data.freqs_measured)/2), 1:20, squeeze(single)')
    
    s = size(single);
    single = reshape(single, [s(2), s(1)])';
    subplot(N,M,4)
    imagesc(data.freqs_measured(1:length(data.freqs_measured)/2), 1:20, squeeze(single)')
    
    subplot(N,M,5)
    
%     size(imgs(jj,ii,:,:))
    plot(data.V(1:101,1), movmean(squeeze(mean(imgs(jj,ii,:,:), 4)), 3))
    subplot(N,M,6)
    plot(data.V(1:101,1), movmean(squeeze(mean(imgs(ii,jj,:,:), 4)), 3))
end