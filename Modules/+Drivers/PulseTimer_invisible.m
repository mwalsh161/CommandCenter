classdef PulseTimer_invisible < handle
    %PulseTimer_invisible Superclass for all pulse sequence hardware
    %Properties:
    %   clk: internal or external clock rate of pusle sequence hardware.
    %   resolution: timining resolution of pulse sequence hardware.
    %   minDuration: minimum pusle duration of pulse sequence hardware. 
    %Methods:
    %   reset: reset device to default settings
    %   start: run pulse sequence 
    %   load: load pulse sequence program into memory of puslse timing
    %   hardware
    %   stop: stop pulse sequence and output default value (low).
        
    properties(Abstract)
        clk;         % MHz
        % resolution;  % ns
        % minDuration; % Minimum duration in ns
        % maxRepitiions; % Maximum number of repitions
    end
    
    methods(Abstract)
        
        function obj = PulseTimer_invisible()
        end  
        
        function reset(~,varargin)
            % reset timing device (may have different definitions depending
            % on device)
            error('Method Reset not defined')
        end
        
        function start(~,varargin)
            % start pulse sequence
            error('Method Start not defined')
        end
        
        function load(~,varargin)
            % load pusle sequence to hardware
            error('Method Load not defined')
        end
         
        function stop(~,varargin)
            % stop the pulse sequence 
            error('Method Stop not defined')
        end
        
    end
    
end

    