classdef Sweeping < Base.Module
    % SWEEPING Abstract Class for Sweeping.
    % This is currently empty because Base.Sweeps might not fit in nicely with the Base.Module architecture of
    % CommandCenter. Might be better to have Sweeping own all Sweeps at runtime.
    
    properties(Constant,Hidden)
        modules_package = 'Sweeping';
    end
end

