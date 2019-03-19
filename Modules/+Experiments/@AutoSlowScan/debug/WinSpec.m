classdef WinSpec < handle
    methods
        function spec = start(obj, varargin)
            spec = spectrumload('Spec_44.SPE');
            spec.x = spec.x+0.1*randn; %shift spectrum by a random amount
        end
    end
end