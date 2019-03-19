classdef wavemeter < handle
    methods
        function freq = GetFrequency(obj)
            freq = 470.9576e12+100e9*(randn);
            fprintf('Wavemeter measured %i\n',freq)
        end
    end
end