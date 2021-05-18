classdef PM100 < Modules.Driver
    % Interface to Thorlabs PM100 power meter
    
    properties(GetObservable, SetObservable)
        idn         = Prefs.String('', 'readonly', true, 'help_text', 'Identifier for the powermeter.');
        
        wavelength  = Prefs.Double(NaN, 'allow_nan', true, 'unit', 'nm', 'set', 'set_wavelength',               'help_text', 'Calibration wavelength to account for the gain spectrum of the powermeter.');
        freq        = Prefs.Double(NaN, 'allow_nan', true, 'unit', 'Hz', 'set', 'set_measure_frequency',        'help_text', 'Frequency of measurement.');
        averages    = Prefs.Double(NaN, 'allow_nan', true, 'unit', '#',  'set', 'set_average_count',            'help_text', 'Number of measurements to average per returned reading.');
        
        power       = Prefs.Double(NaN, 'allow_nan', true, 'unit', 'mW', 'get', 'get_power', 'readonly', true,  'help_text', 'Last reading.');
        refresh     = Prefs.Button('Poll Powermeter', 'set', 'set_refresh', 'help_text', 'Poll the powermeter for a new reading.');
        
    end
    
    properties %(Access=private, Hidden)
        channel;
        id;
        timeout = .1;
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
            pause(0.05)
        end
        
        function obj = PM100(varargin)
            obj.id = findInstrument('0x8072'); % model number for the PM100
%             obj.id = findInstrument('0x8076'); % model number for the PM100
            obj.id
            obj.channel = visa('ni', obj.id);
            obj.channel.Timeout = obj.timeout;
            obj.channel
            
            obj.command('SENS:POW:UNIT W');     % Make sure that we are measuring power.
            
            obj.idn =           obj.get_idn;
            obj.wavelength =    obj.get_wavelength;
            obj.freq =          obj.get_measure_frequency;
            c = obj.get_average_count
            obj.averages =      obj.get_average_count;
            obj.power =         obj.get_power();
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
            if ~isempty(obj.channel) && isvalid(obj.channel) && strcmp(obj.channel.status,'open')
                fclose(obj.channel);
            end
            delete(obj.channel)
        end

        function command(obj, msg, varargin)
            obj.communicate(msg,false);
        end
        function out = query(obj, msg)
            out = obj.communicate(msg,true);
        end
        
        function out = get_idn(obj, ~)
            out = strtrim(obj.query('*IDN?'));
        end
        
        function wavelength = set_wavelength(obj, wavelength, ~)
            obj.command(sprintf('CORR:WAV %f',wavelength))
            wavelength = obj.get_wavelength();
        end
        function out = get_wavelength(obj, ~)
            out = obj.query('CORR:WAV?');
            out = str2double(out);
        end
        
        function freq = set_measure_frequency(obj, freq, ~)
            obj.command(sprintf('FREQ:RANGE %f',freq));
            freq = obj.get_measure_frequency();
        end
        function out = get_measure_frequency(obj, ~)
            out = obj.query('FREQ:RANGE?');
            out = str2double(out);
        end
        
        function count = set_average_count(obj, count, ~)
            obj.command(sprintf('AVER:COUN %i',count));
            count = obj.get_average_count();
        end
        function out = get_average_count(obj, ~)
            out = obj.query('AVER:COUN?');
            out = str2double(out);
        end
        
        function out = get_power(obj, ~)
            out = obj.query('MEAS:POW?');
            out = str2double(out) * 1e3;   % Convert from watts to milliwatts.
        end
        
        function val = set_refresh(obj, val, ~)
            obj.power = obj.get_power();
        end
    end
    
end

