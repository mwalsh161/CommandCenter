
classdef PulseStreamerMaster < Modules.Driver & Drivers.PulseTimer_invisible
    % PulseStreamerMaster is located in in CommandCenter > Modules >
    % +Drivers > +PulseStreamer
    % The PulseStreamerMaster class is a driver module class which 
    % builds and uploads pulse sequences to the Swabian Pulse Streamer and,
    % optionally, runs them. Pulse sequences can also be run or halted 
    % using hardware or software triggers. 
    % 
    % The PulseStreamerMaster module require the Matlab Toolbox for the
    % Pusle Streamer (provided by Swabian).
    %
    % The constructor of this class accepts two inputs upon instantiation: 
    % the IP address of the hardware and a pulse sequence instruction set
    % written in JSON format. An example of the JSON instruction set format 
    % is given below:
    %
    % {
    % "name":"MyPulseSequence",
    % "units":"ns",
    % "forever":false,
    %  "channels":["channel1","MW Switch","","channel4"],
    % "sequence":[
	% {"flags":[0,0,0,1],"duration":0,"instruction":"CONTINUE","data":null},
    % {"flags":[0,1,1,0],"duration":1,"instruction":"LOOP","data":2},
	% {"flags":[0,0,0,1],"duration":18,"instruction":"CONTINUE","data":null},
	% {"flags":[0,1,0,1],"duration":19,"instruction":"END_LOOP","data":null},
	% {"flags":[0,0,0,1],"duration":20,"instruction":"CONTINUE","data":null},
    % ]
    % }
    %
    % Here "name", "units", and "channels" are human readable descriptors.
    % The "forever" field is a boolean that specifies whether or not to
    % loop the pulse sequence indefinitely.
    %
    % The sequence is defined by four fields:
    % 1. flags: an array of boolean states for the relevant channels.
    % 2. duration: the duration of the pulse for the associated states.
    % 3. data: the span of the loop, i.e., the numer of loop interations.
    % 4. instruction: determines the action to be performed.
    %       i.   CONTINUE: run the associated line of instructions
    %       ii.  LOOP: run the associated line of instructions and all
    %            the instructions between LOOP and END_LOOP for 'data'
    %            iterations. 
    %       iii. END_LOOP: terminate the loop and run the associated
    %            instructions.
    %
    % The above defines a simple programming language (an example
    % of a domain specific language) to describe pulse sequences. 
    % 
    % Typical workflow for running a pulse sequence:
    % 1. Initialize instructions and communication to Pulse Streamer
    % 2. Build pulse sequence from JSON string
    % 3. Load pulse sequence into Pulsestreamer 
    % 4. Run pulse sequence (optional, since this can be done through
    %    software or hardware triggers).
    % 5. Halt pulse sequence (optional).
    % 6. Delete function to deallocate resources for the Pulse Streamer Master object. 
    %
    % Example Code: 
    % ip = '192.168.11.2';
    % filename = 'JSON_sequence.js';
    % json = fileread(filename);
    % PSM = PulseStreamerMaster(ip);
    % PSM.build(json);
    % PSM.load();
    % PSM.run();
    % PSM.delete();
    
    
    % ipAddress='192.168.11.2';
    properties(Constant)
        clk = 1000;         % clock sampling rate
        resolution = 3;  % ns can be s low as 1 nd but output voltage is lower than 3.3V (TTL) so depending on uWave source trigger might be able to go down to 1ns
        minDuration = 2; % ns (can go down to 1ns but output waveform will be distorted). 
        maxRepeats = 2^63-1;  % positive integer value
    end
    properties(SetAccess=private)
        % Object that provides the interface to the
        % Pulse Streamer hardware. this object provides access run, halt
        % and trigger operation, and plotting features for the Pulse
        % Streamer.
        PS;
        %
        builder; %PusleSequenceBuilder object used to build pulse sequences.
        triggerStart; 
        triggerMode;
        % string containing pulse sequence instruction set in JSON format
        json;
        % A fully unrolled sequence of instructions. By "unrolled", we
        % mean that all loops at all depths have been written out as an
        % iteration by iteration sequence of instructions. Note: the 
        % recursive algorithm we use to unroll the loops requires that 
        % the cmd object be passed by reference; that is, we pass the
        % actual object, not a copy of it.
        cmd = Drivers.PulseStreamerMaster.seqCommand();
        map = Drivers.PulseStreamerMaster.seqCommand();
        sequence = [];
        seq_meta = [];
        finalState;
    end
    
    properties(SetObservable,SetAccess=private,AbortSet)
        running = 0;
    end
       
    methods(Static)
         function obj = instance(ip)
             mlock;
             persistent Objects
             if isempty(Objects) %|| ~isvalid(Objects)
                 Objects = Drivers.PulseStreamerMaster.PulseStreamerMaster.empty(1,0);
                 %changed from Object to Objects in above line
             end
             [~,resolvedIP] = resolvehost(ip);
             for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PulseStreamerMaster.PulseStreamerMaster(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
         end 
    end
    
    methods(Access={?Drivers.PulseStreamerMaster.PulseStreamerMaster})

         function obj = PulseStreamerMaster(ip)
         % Constructor for this class.
         % ip:   IP address of hardware
         % json: string containing instructions in JSON format
         %
         % Workflow for constructor:
         % 1. set obj.ipAddress to ip address and obj.json to json string
         % 2. instantiate a PulseStreamer object as the property obj.PS. 
         %    The PulseStreamer class is provided by Swabain. It 
         %    contains stream, trigger, ForceFinal, and start methods which 
         %    enable the loading, running and halting of pulse sequences.
         % 3. instantiate a PSSequenceBuidler object as the property 
         %    obj.builder. PSSequenceBuilder is also provided by Swabian. 
         %    It contains a builder method for building pulse sequences
         %    in the format required by the PulseStreamer class.
        
            obj.PS  = PulseStreamer.PulseStreamer(ip);
            obj.triggerStart = PulseStreamer.TriggerStart.SOFTWARE();
            obj.triggerMode  = PulseStreamer.TriggerRearm.AUTO();
            obj.sequence = obj.PS.createSequence();
            obj.map.command(:)=[];
            obj.cmd.command(:)=[];
            % initialize final state to 0V for all channels.
            obj.finalState= PulseStreamer.OutputState.ZERO;
         end
         
    end
             
    methods(Access=public)
         function build(obj,json)
        % This method converts the instructions in the obj.json to a
        % PulseStreamer sequence object. Meta data for the sequence is 
        % reported in the seq_meta output. Its structure is as follows
        % 
        %  seq_meta: 
        %       seq_meta.channels : 1X8 (channels 0-7). Order of channels
        %       is as follows.
        %                           ['Ch0', 'Ch1', 'Ch2', 'Ch3', 
        %                            'Ch4', 'Ch5', 'Ch6', 'Ch7']
        %       Label for each channel is determined by channel field
        %           E.G. seq_meta.channels = ['532nm', 
        %                                     'Res_Repump','MW1','MW2',
        %                                     'MW3','ORES','1050nm','']
        %                     Ch0 -> 532nm
        %                     Ch0 -> Res_Repump
        %                     Ch0 -> MW1
        %                     Ch0 -> MW2
        %                     Ch0 -> MW3
        %                     Ch0 -> ORES
        %                     Ch0 -> 1050nm
        %
        %                
        %       seq_meta.units:   time units for pulse durations
        %       seq_meta.name:    label for sequence.
        %       seq_meta.forever: boolean indicating whether to
        %       repeat sequence indefinitely until explicitly halted.
        % 
        % The build method workflow is as follows:
        %       1. Determine if json input is a string or a json file name
        %          (a name with extension .js). If it is the name of a JSON 
        %          file, open the file and reads the entire contents into
        %          a single string and replace the obj.json with that
        %          string; otherwise, we assume this is a string in JSON
        %          format.
        %       2. Parse JSON string into
        %               a. json_seq: a cell array of maps (i.e., a list of 
        %                  dictionaries)
        %               b. seq_meta: the remaining meta data for the
        %                  sequnece 
        %       3. Build instruction tree recursively from json_seq using
        %          the decodeInstructions method.
        %       4. Unroll the instruction tree recurrsivley into a 1D cell
        %          array of maps, where each map contains the duration and 
        %          channel flags for that step in the pulse sequence. 
        %       5. Initialize pulse_train, a cell array of dimension
        %          C{num_channels}{1}{length(map_list),2}
        %       6. Fill the cell array with pulse sequence data. 
        %       7. Distribute pulse sequence data for each channel and 
        %          set digital channels of ???pulsestrerer???.
        %       8. Build pulse sequence object.  
        DEBUG = 0;
            
            obj.json  = json;
            depth = 0; % depth of recursion
            index = 1; % index into cell array of intructions 
            pulse_trains = {}; % initialize pulse_train cell array
            
            % Test if obj.json is a file. If a file name, read 
            % file and replace obj.json with the file contents as a
            % single string
            if strcmp(obj.json(end-2:end),'.js')
                obj.json = fileread(obj.json);
            elseif strcmp(obj.json(end-3:end),'.txt')
                %write error checking in the future.
            end
                
            % convert obj.json into a list (actually a cell array) of 
            % ordered maps (json_seq) describing the pulse sequence and 
            % seq_meta
            [json_seq,obj] = obj.readJSON();
            
            %debugging issues if this class cannot inherit from the handle
            %class. 
            if DEBUG > 0
                fprintf('output from readJSON is: \n');
                fprintf('PSM.seq_meta is: \n');
                disp(obj.seq_meta);
            end
            
            % expand list of instructions into a tree or instructions 
            % recurrsively. The result is contained in the object obj.cmd.
            % obj.cmd is passed throughout the code by reference (via a
            % handle). 
            [index] = obj.decodeInstructions(json_seq, obj.cmd);
            
            % unroll the instruction tree and all loops recursively
            % into a properly ordered cell array of maps. Each map contains 
            % the instructions for a pulse sequence step (duration and flag 
            % fields). 
            obj.unroll_tree(obj.cmd,obj.map);

            % -------------------------
            % BUILD PULSE TRAINS
            % A pulse train is a list
            % comprising an alternating
            % sequence of duration 
            % followed by flag, that is,
            % channel state, 0 (low) or 
            % 1 (high).
            % -------------------------
            % initialize pulse_trains (a cell array), to be filled with 
            % an alternating sequence of duration and flag, using the 
            % unrolled instructions in map.command.
            ch_train = cell(length(obj.map.command),2);
   
             for kk = 1:1:length(obj.seq_meta.channels)
                 pulse_trains{end+1} = {ch_train}; 
             end
                 
            % fill pulse trains
            for ii = 1:1:length(obj.map.command)
                % for each channel fill the pulse duration and flag
                % (channel state) into the pulse_trains cell array.
                flags     = obj.map.command{ii}('flag');
                duration  = obj.map.command{ii}('duration');
                for jj = 1:1:length(obj.seq_meta.channels)
                    state = flags(jj);
                    pulse_trains{jj}{1}{ii,1} = duration;
                    pulse_trains{jj}{1}{ii,2} = state;

                end   
            end
            
            % Build the digital pattern (a sequence of duration,
            % channel state pairs in that order) for each channel.
            for kk = 1:1:length(obj.seq_meta.channels)
                ch = kk-1;
                digitalPattern = pulse_trains{kk}{1}; 
                obj.sequence.setDigital(ch, digitalPattern);
            end    
        end  
        
        function plot(obj)
            %plot the sequence
            obj.sequence.plot();     
        end
        
        
        function load(obj,program) 
        % The load method converts the sequence object to the properly
        % formated 64 bit string and uploads this to the xilinx chip in the
        % pulse streamer via an eithernet connection managed by a hardware
        % server.
        
            obj.build(program);
            obj.plot;
            start = obj.triggerStart;%initialize the trigger to be software defined
            mode  = obj.triggerMode; % initialize the trigger to be rearmed after each run.
            obj.PS.setTrigger(start, mode); % set triggers
            
            % upload sequence to hardware, but do not run the sequence.
            obj.PS.stream(obj.sequence,obj.seq_meta.repeat,obj.finalState); 
        end
        
        
        function start(obj)
            % starts the sequence if the sequence was uploaded with the
            % PSStart.Software option
            
%             % Get caller info
%             a = dbstack('-completenames');
%             caller = strsplit(a(end).file,filesep);
%             prefix = '';
%             for i = 1:numel(caller)
%                 if numel(caller{i}) && caller{i}(1)=='+'
%                     prefix = [prefix caller{i}(2:end) '.'];
%                 end
%             end
%             [~,name,~]=fileparts(caller{end});
%             caller = [prefix name];
            obj.PS.startNow();
%             obj.running = caller;
        end
        
        function stop(obj)
            %stops the PulseStreamer
            % Interrupt the sequence and set the final state of the 
            % hardware. This method does not modify the final state if 
            % the sequence has already finished. This method also releases 
            % the hardware resources of the Pulse Streamer and, therefore, 
            % allows for faster upload sequence during next call of 
            % "stream" method.
            obj.PS.forceFinal()
            if obj.PS.isStreaming() == 1 
                obj.PulseStreamerHandle.PS.constant(obj.finalState);
            end
        end
        
        function reset(obj)
            obj.PS.reset();  
        end
        
        function [index] = decodeInstructions(obj, json_seq, cmd, depth, index)
        % NOTE: we shall use list and cell array interchangeably.
        % NOTE: cmd is the variable in which data is appended to it upon
        % recursion. To ensure the cmd is appropriately appended the
        % property obj.cmd is passed to decodeInstructor when this function
        % is called. Whereas in the recursive step within this defintion
        % the local variable cmd is passed to decodeInstructions.
        % Decode instruction takes in a cell array of maps (json_seq), 
        % where each map contains the information in a single line of the 
        % JSON string and builds a tree structure that describes the
        % program to be executed that yields ultimately the pulse
        % sequences. This method handles arbitrary sequences of nested 
        % LOOP, END_LOOP, and CONTINUE instructions. The method is called
        % recursively for each loop instruction.
            
            % When DEBUG = 0 then report the length cmd.command, the recursion depth,
            % the index of the current instuction line and the instruction.
            DEBUG = 0;
            
            if DEBUG > 0
                %a = length(json_seq);
                %fprintf('length of JSON string %i\n\n',a);
                %fprintf('number of args %i\n\n',nargin);
            end
           
           % When DEBUG = 0 notify user they have entered the
           % decodeInstructions method.
           if DEBUG > 0
               fprintf('Enter decodeInstructions function\n');
           end
           
           % default values for recurrsion depth and instruction index
           switch nargin
               case 3
                   depth = 0;
                   index = 1;
           end
           
           % When the index has reached or surpassed the number of
           % instructions then exit decodeInstructions and return values.
           if index >= length(json_seq)
               return;
           end
           
           % get current instruction 
           instruction = json_seq{index}('instruction');
           
           % Prior to any recursive calls to decodeInstructions create an
           % empty cell array (similar to a list in python) when the
           % instruction is a LOOP.
           
           % NOTE: we shall use list and cell array interchangeably.
           
           depth = depth + 1; 
           if depth == 1
               % create empty list only if first instruction is a LOOP
               if strcmp(instruction, 'LOOP')
                   cmd.append(Drivers.PulseStreamerMaster.seqCommand());
               end
           % The number of nested loops should never exceed 10 since 
           % the pulse blaster has a maximum allowable nesting depth of 8. 
           elseif depth > 10
               return 
           end


           % if the last element of cmd is a list, then get that list
           % otherwise use the list cmd directly. this takes into
           % account the cases where CONTINUEs may not reside within
           % LOOPs.
           c_cmd = cmd;

           % verify cmd isn not empty, otherwise you will keep nesting lists
           % unwantedly 
           if length(cmd.command) > 0
               % Is the last element in cmd a cell array of maps
               if isa(cmd.command{end}, 'Drivers.PulseStreamerMaster.seqCommand')
                   c_cmd = cmd.command{end};
               end
           end

           %Debugging: report the length of cmd.command to track its growth
           if DEBUG > 0
               fprintf('CMD length is: %i\n\n',length(cmd.command))
           end
           
           % add the instruction at index in the JSON file to the
           % current list of instructions
           c_cmd.append(json_seq{index});
           
           %Debugging: report recursion depth, current instruction and
           %instruction index.
           if DEBUG > 0
               fprintf('depth = %5d\tinstruction: %s, %d\n',depth,instruction,index);
           end

           % loop over the instructions in the json list
           while index < length(json_seq)
               index = index + 1; % IMPORTANT: remember to increment index into json list

               % get instruction type
               instruction = json_seq{index}('instruction');
               
               %Debugging: report recursion depth, current instruction and
               %instruction index.
               if DEBUG > 0
                   fprintf('depth = %5d\tinstruction: %s, %d\n', depth,instruction,index);
               end

               % Decide what to do depending on instruction type
               if strcmp(instruction,'END_LOOP')
                   c_cmd.append(json_seq{index});
                   % we must return in order that decodeInstructions
                   % terminates so that the decoder can continue to
                   % the next json instruction
                   return % Important, this is a terminating case 
                          % for the recursion

               elseif strcmp(instruction,'LOOP')
                   % since this is a loop, create a new empty list to
                   % receive the instructions for this loop.
                   % IMPORTANT: the value of index can change within
                   % decodeInstructions, so we must return it
                   c_cmd.append(Drivers.PulseStreamerMaster.seqCommand)

                   %Debugging: report current instruction data.
                   if DEBUG > 0
                    fprintf('In loop current command is\n')
                    disp(c_cmd(end))
                   end
                   index = obj.decodeInstructions(json_seq,c_cmd(end),depth,index);

                   %Debugging: report current index.
                   if DEBUG > 0
                       fprintf('index %d\n', index);
                   end

               elseif strcmp(instruction,'CONTINUE')
                   %since this is a continue statement we will simply
                   %append the instruction data to the cmd.(remember c_cmd
                   %is handle for cmd).
                   c_cmd.append(json_seq{index});

               else
                   error('** error decoding JSON file\n')

               end
           end      
        end

        
        function unroll_tree(obj,cmd,map,depth)
            % unroll_tree rolls all the instructions in the instruction
            % tree into a 1 dimensional cell array of maps. 
            % NOTE: cmd and map are the variables in which data is appended to each
            % upon recursion. To ensure the cmd and map are appropriately appended the
            % property obj.cmd and obj.map are passed to unroll_tree when this function
            % is called. Whereas in the recursive step within this defintion
            % the local variables cmd.command{c} and map are passed to decodeInstructions.
            
            DEBUG = 0;
            %DEBUGGING: reprot when unroll_tree function has been called.
            if DEBUG>0
                fprintf('\n\nIn unroll_tree\n');
            end
            
            %Default values for map and depth.
            switch nargin
                case 3
                    depth = 0;
            end
            
            % Debugging: grow/ concatentate a string of tabs every time 
            % unroll_tree recurses. Proves pretty printing to ilustrate 
            % loop nesting.
            if DEBUG > 0
                tab = '';
                for i=1:1:depth      
                    tab = strcat('...',tab);
                end
            end

            % loop over top level instructions of abstract syntax tree, 
            % here called cmd
            for c = 1:1:length(cmd.command)
                % if current instruction is a list of instructions, then
                % loop over those instructions
                
                % Debugging: Confirm tht execute_loop should be ran.
                if DEBUG > 1
                    fprintf('Condition to enter execute loop true? ');
                    disp(isa(cmd.command{c},'Drivers.PulseStreamerMaster.seqCommand'))
                end
                
                if isa(cmd.command{c},'Drivers.PulseStreamerMaster.seqCommand')
                    obj.execute_loop(cmd.command{c},map,depth);
                else
                    % this is not a list, but a map
                    
                    % Debugging: report recursion depth, current instruction and
                    %i nstruction index.
                    if DEBUG > 0
                        fprintf('%s%s: duration = %i, flags = %i %i %i %i\n', ...
                                tab,                                 ...
                                cmd.command{c}('instruction'),                           ...
                                cmd.command{c}('duration'),                              ...
                                cmd.command{c}('flag').');  
                    end
                  
                    obj.map.append(cmd.command{c});
              
                end
            end
        end

        
        function printTree(obj, cmd, depth)
        %   Print the Tree of instructions
        
            % Default arguments
            switch nargin
                case 2
                    depth = 0;
            end
            
            % track recurrsion depths 
            %kick out printTree if recurrsion depth exceeds 10
            depth = depth + 1;
            if depth == 1
                fprintf('\n');
            elseif depth > 10
                return
            end
            fprintf('depth: %i\n' , depth);

            tab = '';
            for i=1:depth

                tab = strcat('...',tab);
            end

            % Loop acrous length of cmd cell array (list). If a list is found then
            % printTree of that list. Please note that the seqCommand is a
            % hadnle class which allows for the concatenation of any item
            % type (i.e. itis analogous to a list).
            for ii = 1:1:length(cmd.command)
                c = cmd.command{ii};
                if isa(c,'Drivers.PulseStreamerMaster.seqCommand')
                   obj.printTree(c,depth);
                else 
                    % Otherwise the current intstruction is a map
                    % print is and the depth layer, flags and index.
                    fprintf('%s%s: duration = %i, flags =  %i %i %i %i, data = %d\n', ...
                       tab,                                 ...
                       c('instruction'),                           ...
                       c('duration'),                              ...
                       c('flag').',                                 ...
                       c('data'));  
                end
            end
        end
        
        function map = execute_loop(obj,cmd,map,depth)
 
            DEBUG = 0;

            if DEBUG > 1
                fprintf('\n\nIn execute_loop\n');
            end
            
            % Default arguments 
            switch nargin
                case 2
                    map = Drivers.PulseStreamerMaster.seqCommand();
                    depth = 0;
                case 3
                    depth = 0;
            end
            
            %increment recurssion depth and return if depth exceeds 10.
            depth = depth+1;

            if depth > 10
                return; 
            end
            
            if DEBUG > 0 
                tab = '';
                for i=1:depth
                    tab = strcat('...',tab);
                end
            end
            
            %current loop instruction. By default if this function is
            %executed then the first instruction in the list is LOOP.
            c = cmd.command{1};

            % LOOP instruction
            %Debugging: Report instruction in loop
            if DEBUG > 0 
                    fprintf('%s%s: duration = %i, flags =  %i %i %i %i, data = %d\n', ...
                       tab,                                 ...
                       c('instruction'),                           ...
                       c('duration'),                              ...
                       c('flag').',                                 ...
                       c('data'));                                

            end
            
            %error handling
            if ~strcmp(c('instruction'),'LOOP')
                error('Expected LOOP instruction, but found %s\n', c('instruction'))
            end
            
            %Debugging: Current map to concatenate
            if DEBUG > 1
                fprintf('Current map to be appended: ');
                disp(c)
            end
            
            %append current map 
            map.append(cmd.command{1});

            %Debugging: Display updated list of instruction maps
            if DEBUG > 1
                fprintf('Current list of maps: ');
                disp(map)
            end

            % Implement loop
            loop_cmd = cmd.command;
            span = c('data'); %number of times to increment loop

            for ii = 1:1:span
                % loop over instructions for current loop
                % excluding the LOOP and END_LOOP instructions

                if DEBUG > 1
                    disp(length(loop_cmd))
                end
                 
                %skip 1 and last instruction set since these are not looped
                %over (i.e. the instructions on LOOP and END_LOOP are
                %always ran before and after the curret loop, respectively.
                %Loop over remainging instructions.
                for jj = 2:1:(length(loop_cmd)-1)

                    if DEBUG > 1
                        fprintf('current jj: ');
                        disp(jj)
                    end
                    
                    %if an instruction within this loop is LOOP then
                    %recurse into execute_loop. 
                    if isa(loop_cmd{jj},'Drivers.PulseStreamerMaster.seqCommand')

                        if DEBUG > 1
                            fprintf('current loop instruction: ');
                            disp(loop_cmd{jj})
                        end
                        obj.execute_loop(loop_cmd{jj},map,depth);
                        % continue to next instruction for this loop
                        continue
                    end
                    % Otherwise current instruction must be a CONTINUE
                    % so just execute it
                    c = loop_cmd{jj};
                    
                    %append map of continue instruction.
                    map.append(c);

                    % Debugging: report recursion depth, current instruction and
                    % instruction index.
                    if DEBUG > 0

                        fprintf('%s%s: duration = %i, flags =  %i %i %i %i\n', ...
                            tab,                                 ...
                            c('instruction'),                           ...
                            c('duration'),                              ...
                            c('flag').');  
                    end

                    %If instruction is not CONTINUE then throw error.
                    if ~strcmp(c('instruction'),'CONTINUE')
                        error('Expected CONTINUE instruction, but found %s\n', ...
                            c('instruction'))
                    end 
                end       
            end

            % END_LOOP instruction is last instruction in list of loop
            % instructions
            c = cmd.command{end};
            
            % append map of continue instruction.
            map.append(c);
            
            % Debugging: report recursion depth, current instruction and
            % instruction index.
            if DEBUG > 0

                fprintf('%s%s: duration = %i, flags = %i %i %i %i\n', ...
                        tab,                                 ...
                        c('instruction'),                           ...
                        c('duration'),                              ...
                        c('flag').');  
            end
            
            %Throw error last instruction in loop is not 'END_LOOP'
            if ~strcmp(c('instruction'),'END_LOOP')
                error('Expected END_LOOP instruction, but found %s\n', ...
                    c('instruction'))
            end
            
            %Debugging: Notify when exiting execute_loop
            if DEBUG > 0
                fprintf('\n\nExiting execute_loop\n');
            end
        end
        
        function [json_seq,obj] = readJSON(obj)
        % readJSON converts the json string stored in obj.json into a cell
        % array of maps, where each field in the map correspond to the
        % fields in the json string sequence field. The remaining data in
        % the obj.json string is store in seq_meta: a structure data type
        % which houses the channels, units name and forever fields for the
        % pulse sequence. 
        
        DEBUG = 0;
        
            % compile now pass a matlab structure equivalent to
            % the old structure = jsondecode(json_pulse_sequence)
            %json_total = jsondecode(obj.json);
            json_total = obj.json;
            json_struct = json_total.sequence;
           
            
            %initialize the json_seq cell array and fill each element in
            %array with map for each instruction line. 
            json_seq = cell(1,length(json_struct));
            for i=1:1:length(json_struct)
                cells = struct2cell(json_struct(i));
                key_labels = {'flag','duration','instruction','data'};
                json_seq{i} = containers.Map(key_labels,cells);         
            end  

            %return remaining human readabl fields (channels, units, name,
            %forever) to seq_meta
            seq_metadata.channels = json_total.channels;
            seq_metadata.units = json_total.units;
            seq_metadata.name = json_total.name;
            seq_metadata.repeat = json_total.repeat;
            
            obj.seq_meta = seq_metadata;
            
            if DEBUG>0
                fprintf('seq_meta output of readJSON: \n');
                disp(obj.seq_meta);
            end
        end
        

    end
    
    methods
        
           % Destructor method. Clears object properties.
         function delete(obj)
             if obj.PS.isStreaming() == 1 
                 obj.stop()
             elseif obj.PS.hasSequence() == 1
                 obj.stop()
             end
         end
    end
end

