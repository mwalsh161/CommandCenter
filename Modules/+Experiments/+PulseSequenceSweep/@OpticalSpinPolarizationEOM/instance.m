function obj = instance(varargin)
    % This file is what locks the instance in memory such that singleton
    % can perform properly. 
    % For the most part, varargin will be empty, but if you know what you
    % are doing, you can modify/use the input (just be aware of singleton_id)
    mlock;
    persistent Objects
    if isempty(Objects)
<<<<<<< HEAD
        Objects = Experiments.PulseSequenceSweep.OpticalSpinPolarizationEMCCD.empty(1,0);
=======
        Objects = Experiments.PulseSequenceSweep.OpticalSpinPolarizationEOM.empty(1,0);
>>>>>>> 094219f62f8291bc6e2c3d6ced0637af339a0e5a
    end
    for i = 1:length(Objects)
        if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
            obj = Objects(i);
            return
        end
    end
<<<<<<< HEAD
    obj = Experiments.PulseSequenceSweep.OpticalSpinPolarizationEMCCD(varargin{:});
=======
    obj = Experiments.PulseSequenceSweep.OpticalSpinPolarizationEOM(varargin{:});
>>>>>>> 094219f62f8291bc6e2c3d6ced0637af339a0e5a
    obj.singleton_id = varargin;
    Objects(end+1) = obj;
end