function [s] = setup_PB_sequence(obj)
            Integration_time = obj.Integration_time*1e6;
            
            laser_read_time = obj.laser_read_time; %in ns
            
            if strcmp(obj.disp_mode,'verbose')
                nSamples = round(Integration_time/laser_read_time);
            elseif strcmp(obj.disp_mode,'fast')
                nSamples = round(obj.nAverages*Integration_time/laser_read_time);
            else
                error('Unrecognized display mode type.')
            end
            
            % get hw lines for different pieces of equipment(indexed from
            % 0)
            
            [laser_hw,APD_hw,MW_switch_hw] = obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            cLaser = channel('laser','color','g','hardware',laser_hw);
            cAPDgate = channel('APDgate','color','b','hardware',APD_hw,'counter','APD1');
            cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');
            
            %% check offsets are smaller than padding, errors could result otherwise
            
            assert(cLaser.offset(1) < obj.padding,'Laser offset is smaller than padding');
            assert(cAPDgate.offset(1) < obj.padding,'cAPDgate offset is smaller than padding')
            assert(cMWswitch.offset(1) < obj.padding,'cMWswitch offset is smaller than padding')

            
            %% 
            
            % Make sequence
            s = sequence('ECHO_sequence');
            s.channelOrder = [cLaser,cAPDgate,cMWswitch];
            
            % make outer loop to compensate for limit on sequence.repeat
            out_loop = 'out_loop';
            out_val = 1; %temporary placeholder
            n_init_out_loop = node(s.StartNode,out_loop,'type','start');
            
            % implement pi/2 pulse to put in rotating frame
            n_MW = node(s.StartNode,cMWswitch,'delta',obj.padding,'units','ns');
            n_MW = node(n_MW,cMWswitch,'delta',obj.piTime/2,'units','ns');
            
            % wait for the tau time to acquire phase
            n_MW = node(n_MW,cMWswitch,'delta',obj.tau,'units','ns');
            
            % do pi pulse 
            n_MW = node(n_MW,cMWswitch,'delta',obj.piTime,'units','ns');
            
            % wait for the second tau time to acquire phase
            n_MW = node(n_MW,cMWswitch,'delta',obj.tau,'units','ns');
            
            % implement second pi/2 pulse to put in measurement basis
            n_MW = node(n_MW,cMWswitch,'delta',obj.piTime/2,'units','ns');
            
            % Read out state of NV
            n_Laser = node(n_MW,cLaser,'delta',obj.padding,'units','ns');
            n_Laser = node(n_Laser,cLaser,'delta',obj.reInitializationTime,'units','ns');
            
            % APD gate duration to collect counts
            n_APD = node(n_MW,cAPDgate,'delta',obj.padding,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',laser_read_time,'units','ns');
            
            % get normalization data
            n_APD = node(n_Laser,cAPDgate,'delta',obj.padding,'units','ns');
            n_Laser = node(n_Laser,cLaser,'delta',obj.padding,'units','ns');
            n_Laser = node(n_Laser,cLaser,'delta',obj.reInitializationTime,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',laser_read_time,'units','ns');
            
            % End outer loop and calculate repetitions
            n_end_out_loop = node(n_Laser,out_val,'delta',obj.padding,'type','end');
            max_reps = 2^20-1;
            if nSamples > max_reps
                % loop to find nearest divisor
                while mod(nSamples,max_reps) > 0
                    max_reps = max_reps - 1;
                end
                n_end_out_loop.data = nSamples/max_reps;
                s.repeat = max_reps;
            else
                s.repeat = nSamples;
            end
           
        end