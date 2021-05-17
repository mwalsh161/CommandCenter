function fitoptimizetest
    x = linspace(-5, 5, 201);
    
    y = poissrnd(50*exp(-x.*x) + 30*exp(-(x-3).*(x-3)) + 20*exp(-(x-2).*(x-2)));
    
    levellist = .5:.05:.95;
    [x0, xx, xxx] = fitoptimize(x,y);
    
    x0
    
    
    a = subplot(1,2,1);
    plot(x, y, [x0, x0], [min(y) max(y)]);
    hold on
    scatter(xxx, levellist*max(y))
    
    a = subplot(1,2,2);
    yy = movmean(y, 20);
    plot(x, y, x, yy);
    hold on
    [~, x0] = findpeaks(yy, x, 'Annotate', 'peaks');
    findpeaks(yy, x);
    plot([x0(1), x0(1)], [min(y) max(y)]);
end