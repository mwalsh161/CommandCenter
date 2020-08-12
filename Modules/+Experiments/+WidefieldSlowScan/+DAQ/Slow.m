classdef Slow < Experiments.WidefieldSlowScan.DAQ.DAQ_invisible
    methods(Static)
        function obj = instance(varargin)
            % This file is what locks the instance in memory such that singleton
            % can perform properly. 
            % For the most part, varargin will be empty, but if you know what you
            % are doing, you can modify/use the input (just be aware of singleton_id)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Experiments.WidefieldSlowScan.DAQ.Slow.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.WidefieldSlowScan.DAQ.Slow(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = Slow()
%             obj.prefs = [obj.prefs,{'DAQ_dev','DAQ_line','slow_from','slow_to','slow_overshoot','slow_step','Vrange','V2GHz'}];
%             obj.loadPrefs; % Load prefs specified as obj.prefs
% %             obj.get_scan_points();
        end
    end
end