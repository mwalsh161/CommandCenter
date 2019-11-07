classdef PulseTimer_invisible < handle
    %PulseTimer_invisible Superclass for all pulse sequence hardware
    %Properties:
    %   clk: internal or external clock rate of pulse sequence hardware.
    %   resolution: timinig resolution of pulse sequence hardware
    %   minDuration: minimum pulse duration of pulse sequence hardware.
    %   maxRepeats; maximum number of pulse sequence repetitions.
    %Methods:
    %   reset: reset device to default settings
    %   start: run pulse sequence 
    %   load: load pulse sequence program into memory of puslse timing
    %   hardware
    %   stop: stop pulse sequence and output default value (e.g. all channels low).
        
    properties(Constant,Abstract)
        clk;         % clock sampling rate
        resolution;  % ns
        minDuration; % ns
        maxRepeats;  % positive integer value
    end
    
    methods
        function obj = PulseTimer_invisible() 
        end
    end
    methods(Abstract)
        reset(obj) % reset timing device (may have different definitions depending
            % on device)

        start(obj)  % start pulse sequence

        load(obj,program) % load pusle sequence program to hardware

        stop(obj) % stop the pulse sequence     
    end
    
end

    