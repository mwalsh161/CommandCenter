classdef PM100 < Modules.Driver
    % Interface to Thorlabs PM100 power meter
    % Inspired from code by: Michael Walsh (mpwalsh@mit.edu) 2014
    
    properties
        channel;
        id;
        unit_status = 'mW';
    end
    
    methods(Access=private)
        function out = communicate(obj,msg,output)
            out = '';
            if strcmp(obj.channel.status,'closed')
                fopen(obj.channel);
            end
            fprintf(obj.channel,msg);
            if output
                out = fscanf(obj.channel);
            end
            pause(0.05) % Unclear why this was here.
        end
        
        function obj = PM100(varargin)
%             id = findInstrument('0x8072'); % model number for the PM100 (old models; new models are 0x8076)
%             id = findInstrument('0x8076'); % model number for the PM100 (old models; new models are 0x8076)
            id = findInstrument('USB0::0x1313::0x8076::M00841653::INSTR');
            obj.channel = visa('ni', id);
        end
        
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Drivers.PM100();
            end
            obj = Object;
        end
    end
    
    methods
        
        function delete(obj)
            if strcmp(obj.channel.status,'open')
                fclose(obj.channel);
            end
            delete(obj.channel)
        end
        %% Basic Functionality
        function command(obj, msg, varargin)
            obj.communicate(msg,false);
        end
        
        function out = query(obj, msg)
            out = obj.communicate(msg,true);
        end
        
        function out = idn(obj)
            out = obj.query('*IDN?');
        end
        
        function set_wavelength(obj,wavelength)
            obj.command(sprintf('CORR:WAV %f',wavelength))
        end
        
        function out = get_wavelength(obj)
            out = obj.query('CORR:WAV?');
            out = str2num(out);
        end
        
        function set_measure_frequency(obj,freq)
            obj.command(sprintf('FREQ:RANGE %f',freq));
        end
        
        function get_measure_frequency(obj)
            out = obj.query('FREQ:RANGE?');
            out = str2num(out);
        end
        
        function set_average_count(obj,count)
            obj.command(sprintf('AVER:COUN %i',count));
        end
        
        function out = get_average_count(obj)
            out = obj.query('AVER:COUN');
            out = str2num(out);
        end
        
        function [pow, dpow, raw] = get_power(obj, varargin)    % Drivers.PM100.get_power('units', <'mW' or 'dBm'>, 'samples', <positive integer>)
            p = inputParser;
            p.addParameter('units', obj.unit_status, @ischar);
            p.addParameter('samples', 1, @(x)(isnumeric(x) && isscalar(x) && x > 0 && round(x) == x));
            
            parse(p,varargin{:});
            units = p.Results.units;
            samples = p.Results.samples;
            
            if ~strcmp(obj.unit_status, units)  % Move this to seperate function?
                if strcmp(units, 'dBm')
                    obj.command('SENS:POW:UNIT DBM');
                    obj.unit_status = 'dBm';
                elseif strcmp(units, 'mW')
                    obj.command('SENS:POW:UNIT W');
                    obj.unit_status = 'mW';
                else
                    error('PM100 get_power needs valid units "mW" or "dBm"');
                end
            end
            
            raw = NaN(1, samples);
            for ii = 1:samples
                raw(ii) = str2double(obj.query('MEAS:POW?'));
            end
            
            pow = mean(raw);
            dpow = std(raw);
            
            if strcmp(units, 'mW')
                raw = raw * 1e3;
                pow = pow * 1e3;
                dpow = dpow * 1e3;
            end
        end
    end
    
end

