classdef PM100 < Modules.Driver
    % Interface to Thorlabs PM100 power meter
    % Inspired from code by: Michael Walsh (mpwalsh@mit.edu) 2014
    
    properties
        channel;
        id;
        unit_status = 'MW';
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
%             id = findInstrument('0x8072'); % model number for the PM100
            id = findInstrument('0x8076'); % model number for the PM100
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

        function command(obj, msg, varargin)
            obj.communicate(msg,false);
        end
        function out = query(obj, msg)
            out = obj.communicate(msg,true);
        end
        function out = get_idn(obj)
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
        
        function out = get_power(obj, units)
            if ~strcmp(obj.unit_status, units)
                if strcmp(units, 'DBM')
                    obj.command('SENS:POW:UNIT DBM');
                    obj.unit_status = 'DBM';
                elseif strcmp(units, 'MW')
                    obj.command('SENS:POW:UNIT W');
                    obj.unit_status = 'MW';
                else
                    error('PM100 get_power needs valid units "MW" or "DBM"');
                end
            end
            
            out = obj.query('MEAS:POW?');
            out = str2num(out);
            if strcmp(units, 'MW')
                out = out * 1e3;
            end
        end
    end
    
end

