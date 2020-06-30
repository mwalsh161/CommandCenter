function greenPowerSweep(managers)
%     EX = [1000 500 100];
%     GG = 10.^(-2:.5:1.5);
%     OO = 0:20:180;
    EX = [500 100 50];
    GG = 10.^(-2:1:1);
    OO = 0:45:180;
    
    GG = GG(end:-1:1);
    OO = OO(end:-1:1);
    
    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;
    wheel = Drivers.ArduinoServo.instance('localhost', 2); % Which weaves as it wills.
    
    C.arm()
    C.on()
    
    EX
    GG
    OO
    
    S = Sources.msquared.EMM.instance;
    
    THz = 498;
    dwl = .01;
    retune = true;
    
    percentrange = 30;
    
    E = Experiments.WidefieldSlowScan.ClosedDAQ.instance;
    
    for ex = EX
        for g = GG
            for o = OO
                disp(['Exposure time is ' num2str(ex) ' ms'])
                disp(['Green power is ' num2str(g) ' mW'])
                disp(['Orange angle is ' num2str(o) ' deg'])

                cam.exposure = ex;
                C.power = g;
                wheel.angle  = o;
                
                if retune
                    E.loadDAQ();
                    E.setLaser(0); % Add try catch?
                    pause(2)
                    
                    needsretune = true;
                    
                    while needsretune
                        try
                            centerpercent = E.THz2percent(THz);

                            halffullpercentrange = (percentrange + 20)/2;

                            fprintf('Range from %f%% to %f%% for\n      from %f THz to %f THz with\n     Base %f%% and %f THz is...\n',...
                                centerpercent - percentrange/2, centerpercent + percentrange/2,...
                                E.percent2THz(centerpercent - percentrange/2), E.percent2THz(centerpercent + percentrange/2),...
                                S.GetPercent, S.getFrequency);

                            if centerpercent - halffullpercentrange < 0 || centerpercent + halffullpercentrange > 100
                                disp('    ...invalid');
                            else
                                disp('    ...valid');
                                needsretune = false;
                            end

                            if needsretune % If still needs retune, then retune.
                                S.TuneSetpoint(THz + 2*dwl);
                                S.TuneSetpoint(THz + (rand-.5)*dwl/40);

                                pause(2)
                            end
                        catch err
                            disp('    ...returning failed:');
                            disp(err.message);
                        end
                    end
                    
                    centerpercent = E.THz2percent(THz); % Add try catch?
                    
                    E.from =    centerpercent - percentrange/2;
                    E.to =      centerpercent + percentrange/2;
                    
%                     try
%                         S.TuneSetpoint(THz);
%                     catch
% 
%                     end
%                     pause(.5)
%                     S.GetPercent
%                     
%                     stabilitygood = false;
%                     attempt = 1;
% 
%                     while ~stabilitygood 
%                         pause(2)
%                         
%                         stabilitygood = true;
%                         
%                         for stabcheck = 1:3
%                             pause(.5);
%                             p = S.GetPercent;
%                             stabilitygood = stabilitygood && abs(p - 50) < 3;
%                             disp(['    Check ' num2str(stabcheck) '/3: ' num2str(p)]);
%                         end
%                         
%                         if ~stabilitygood
%                             disp(['Attempt ' num2str(attempt) '!']);
%                             attempt = attempt + 1;
%                             try
%                                 S.TuneSetpoint(THz + 2*dwl);
%                                 S.TuneSetpoint(THz + (rand-.5)*dwl/40);
%                             catch
%                             end
%                         end
%                     end
                end

                managers.Experiment.run()
                
                if managers.Experiment.aborted
                    error('User aborted.');
                end
            end
        end
    end
end 