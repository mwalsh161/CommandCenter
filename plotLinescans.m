function plotLinescans
    d = 'Z:\Diamond\EG345\2021_10_01 M4 Chiplet Screening\Wide Diamond';
    
    files_ = dir(d);
    files = {files_.name};
    
    figure
    
    for ii = 1:length(files)
        if files{ii}(1) ~= '.'
            data = load([d filesep files{ii}]);
            plot(data.data.data.data.freqs_measured, data.data.data.data.sumCounts);
            hold on
            
            [vals, confs, fit_results, gofs] = fitpeaks(data.data.data.data.freqs_measured', data.data.data.data.sumCounts', 'fittype', "voigt");
            
            vals
            
            plot(fit_results{1})
        end
    end
end