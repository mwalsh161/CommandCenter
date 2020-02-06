function obj = instance(varargin)
    % This file is what locks the instance in memory such that singleton
    % can perform properly. 
    % For the most part, varargin will be empty, but if you know what you
    % are doing, you can modify/use the input (just be aware of singleton_id)
    mlock;
    persistent Objects
    if isempty(Objects)
        Objects = Experiments.PLEwide.empty(1,0);
    end
    for i = 1:length(Objects)
        if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
            obj = Objects(i);
            return
        end
    end
    obj = Experiments.PLEwide(varargin{:});
    obj.singleton_id = varargin;
    Objects(end+1) = obj;
end