classdef rl < handle
    properties
        spectrometer = WinSpec
        path
        c = 3e17;
    end
    methods
        function turn_on(obj)
            disp('red laser on');
        end
        function turn_off(obj)
            disp('red laser off');
        end
        function LaserMove(obj,target,type)
            
            if strcmpi(type,'spectrometer')
                laserspec = spectrumload('Spec_44.SPE');
                laserspec.x = laserspec.x+0.5*randn; %shift spectrum by a random amount %take spectrum
                laserloc = obj.c./SpecPeak(laserspec); %from here out, all is in frequency, not wavelength
                LaserFreqSet = laserloc(1); %first laser setpoint is presumed to be where the laser is measured to be
                while abs(laserloc(1) - target) >= 1e11 %threshold for catching NV in scan
                    if abs(laserloc(1) - target) >= 1e12; %coarse threshold
                        LaserFreqSet = LaserFreqSet-(laserloc(1)- target); %take difference, use to set again
                    else %we're close; use small steps
                        LaserFreqSet = LaserFreqSet - 10e9*sign(laserloc(1)-target); %small 10 GHz step in correct direction
                    end
                    laserspec = spectrumload('Spec_44.SPE');
                    laserspec.x = laserspec.x+0.5*randn; %shift spectrum by a random amount %take spectrum
                    laserloc = obj.c./SpecPeak(laserspec); %SpecPeak requires [x,y] - need spectrumload?
                    fprintf('Laser peak moved to %i\n',laserloc)
                end
                
            elseif strcmpi(type,'wavemeter')
                laserloc = 470.9576e12+100e9*(randn);
                fprintf('Wavemeter measured %i\n',laserloc)
                LaserFreqSet = laserloc;
                while abs(laserloc - target) >= 1e11 %threshold for NV being well centered
                    if abs(laserloc - target) >= 1e12; %coarse threshold
                        LaserFreqSet = LaserFreqSet-(laserloc-target); %take difference, use to set again
                    else %we're close; use small steps
                        LaserFreqSet = LaserFreqSet - 10e9*sign(laserloc-target); %small step in correct direction
                    end
                    %obj.nidaq.VelocityFreq(LaserFreqSet);
                    laserloc = 470.9576e12+100e9*(randn);
                    fprintf('Wavemeter measured %i\n',laserloc)
                end
                
            else
                assert(0,'Laser tuning method not recognized.')
            end
        end
    end
end