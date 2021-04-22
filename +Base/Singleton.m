classdef Singleton < handle
    %SINGLETON Abstract Class for Singleton OOP Design Pattern
    %  Ensures a class only has one instance and provide a global point of
    %  access to it.
    %
    properties(SetAccess=protected)
        singleton_id
    end
    
    methods(Abstract, Static)
        % This method serves as the global point of access in creating a single instance *or* acquiring a reference to the singleton.
        % If the object doesn't exist, create it otherwise return the existing one in persistent memory.
        obj = instance();
    end
    methods
        % Constructor analyzes the stack to make sure subclass is called correctly.
        function obj = Singleton
            err = {};
            % Use metaclass to inspect module
            mc = metaclass(obj);
            name = strsplit(mc.Name,'.');
            name = name{end};
            
            % Determine that instance lead to call of constructor (i.e. it is on the stack)
            d = dbstack;
            d_names = {d.name}; % Names without prefix
            ind = cellfun(@(a)strcmp(a,[name '.instance']),d_names); % instance method
            if isempty(ind)
                err{end+1} = '-Singleton must be called by the instance method.';
            end
            
            % Inspect privileges of constructor
            constructor = cellfun(@(a)strcmp(a,name),{mc.MethodList.Name});
            constructor = mc.MethodList(constructor);
            if ~iscell(constructor.Access) && ~ismember(constructor.Access,{'private','protected'})
                err{end+1} = '-Constructor must have Access=private or protected or specify cell array of meta classes.';
            end
            
            % Make sure instance method locked it
            if ~mislocked([mc.Name '.instance'])
                err{end+1} = '-Singleton instance method should call mlock to keep function persistent variable in memory.';
            end
            if ~isempty(err)
                err = [{[mc.Name ':']} err];
                error(strjoin(err,'\n'))
            end
        end
        function delete(obj)
            % Note this could be a problem if multiple instances are open
            munlock(class(obj));
            if mislocked(class(obj))
                warning('SINGLETON:delete','Was not able to purge function from memory!')
            end
        end
    end
    
end