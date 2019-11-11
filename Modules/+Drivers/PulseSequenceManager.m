classdef PulseSequenceManager < Modules.Driver
    %PulseSequenceManager Combines PulseSequences with the nidaq and
    %PulseBlaster hardware.
    %   Detailed explanation goes here
    
    properties
        PS              % Handle to PulseSequence
    end
    properties(SetAccess=immutable,Hidden)
        pb              % PulseBlaster handle
        ni              % NIDAQ handle
    end
    
    methods(Static)
        function obj = instance(PulseBlaster_ip,NIDAQ_dev)
            mlock;
            id = {PulseBlaster_ip,NIDAQ_dev};
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PulseSequenceManager.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PulseSequenceManager(PulseBlaster_ip,NIDAQ_dev); %modified 11/10/19
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = PulseSequenceManager(PulseBlaster_ip,NIDAQ_dev)
            obj.ni = Drivers.NIDAQ.dev.instance(NIDAQ_dev);
            obj.pb = Drivers.PulseBlaster.Remote.instance(PulseBlaster_ip);
            %obj.pb = Drivers.PulseStreamerMaster.PulseStreamerMaster.instance(PulseBlaster_ip);
        end
    end
    methods
        function set.PS(obj,val)
            assert(isa(val,'sequence'),'Must be of type sequence.')
            obj.PS = val;
        end
        function load(obj,filename)
            item = load(filename,'seq');
            obj.PS = item.seq;
        end
        function initialize(obj,varargin)
            % Same inputs as sequence.compile
            [instructionSet,~,repeat] = obj.PS.compile(varargin{:});
            obj.pb.load(instructionSet);
            % Calculate buffers and samples for NIDAQ
        end
        function run(obj)
            
        end
        function streamData(obj,callback)
            
        end
        function abort(obj)
            
        end
    end
end

