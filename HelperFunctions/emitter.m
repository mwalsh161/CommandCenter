classdef emitter < handle
   properties
       loc = NaN(1,2)
       spec
       survey = struct('percents',{},'volts',{},'freqs',{},'counts',{},'stds',{},'averages',{},'ScanFit',{})
       region = struct('span',{},'slow',{},'done',false,'err',{})  % This does not set done to false
       status = '';
       err
   end
end