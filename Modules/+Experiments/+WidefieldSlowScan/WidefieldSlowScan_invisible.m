classdef WidefieldSlowScan_invisible < Modules.Experiment
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        imaging = Modules.Imaging.empty(1,0);
    end
    properties
        scan_points = []; %frequency points, either in THz or in percents
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        vars = {'scan_points'}; %names of variables to be swept
    end
    properties(SetAccess=protected,Hidden)
        data = [] % subclasses should not set this; it can be manipulated in GetData if necessary
        meta = [] % Store experimental settings
        abort_request = false; % Flag that will be set to true upon abort. Used in run method.
        pbH;    % Handle to pulseblaster
        nidaqH; % Handle to NIDAQ
    end

%     properties(Abstract,Constant)
% %         xlabel; % For plotting data
%     end
    methods
        function obj = WidefieldSlowScan_invisible()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','imaging'}]; %additional preferences not in superclass
        end
        
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;
            % Edit here down (save data to obj.data)
            % Tips:
            % - If using a loop, it is good practice to call:
            %     drawnow; assert(~obj.abort_request,'User aborted.');
            %     as frequently as possible
            % - try/catch/end statements useful for cleaning up
            % - You can get a figure-like object (to create subplots) by:
            %     panel = ax.Parent; delete(ax);
            %     ax(1) = subplot(1,2,1,'parent',panel);
            % - drawnow can be used to update status box message and any plots

            % Assert user implemented abstract properties correctly
%             assert(iscell(obj.vars) && ~isempty(obj.vars) && min(size(obj.vars))==1,'Property "vars" should be a 1D cell array with at least one value!');
%             assert(all(cellfun(@ischar,obj.vars)),'Property "vars" should only contain strings');
%             check_prop_exists = cellfun(@(a)isprop(obj,a),obj.vars);
%             assert(all(check_prop_exists),sprintf('Properties not found in obj that are listed in "vars":\n%s',...
%                 strjoin(obj.vars(check_prop_exists),newline)));
%             assert(numel(obj.nCounterBins)==1 && isnumeric(obj.nCounterBins) && floor(obj.nCounterBins)==obj.nCounterBins,...
%                 'Property "nCounterBins" should be a single integer');

%             numVars = length(obj.vars);
%             varLength = NaN(1,numVars);
%             for i = 1:numVars
%                 varLength(i) = length(obj.(obj.vars{i}));
%             end

            obj.data.images = NaN([obj.imaging.width, obj.imaging.height, length(obj.scan_points)]);

            obj.meta.prefs = obj.prefs2struct;
            for i = 1:length(obj.vars)
                obj.meta.vars(i).name = obj.vars{i};
                obj.meta.vars(i).vals = obj.(obj.vars{i});
            end
            obj.meta.position = managers.Stages.position; % Stage position

%             f = figure('visible','off','name',mfilename);
%             a = axes('Parent',f);
%             p = plot(NaN,'Parent',a);

            try
                obj.PreRun(status,managers,ax);

                % Construct APDPulseSequence once, and update apdPS.seq
                % Not only will this be faster than constructing many times,
                % APDPulseSequence upon deletion closes PulseBlaster connection
%                 indices = num2cell(ones(1,numVars));
%                 apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder')); %create an instance of apdpulsesequence to avoid recreating in loop
%                 statusString = cell(1,numVars);
%                 for j = 1:obj.averages
%                     for i = 1:prod(varLength)
%                         drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
%                         [indices{:}] = ind2sub(varLength,i); % this does breadth-first
%                         for k=1:numVars
%                             statusString{k} = sprintf('%s = %g (%i/%i)',obj.vars{k},obj.(obj.vars{k})(indices{k}),indices{k},varLength(k));
%                         end
%                         status.String = [sprintf('Progress (%i/%i averages):\n  ',j,obj.averages),strjoin(statusString,'\n  ')];
% 
%                         % BuildPulseSequence must take in vars in the order listed
%                         pulseSeq = obj.BuildPulseSequence(indices{:});
%                         if pulseSeq ~= false % Interpret a return of false as skip this one (leaving in NaN)
%                             pulseSeq.repeat = obj.samples;
%                             apdPS.seq = pulseSeq;
% 
%                             apdPS.start(1000); % hard coded
%                             apdPS.stream(p);
%                             dat = reshape(p.YData,obj.nCounterBins,[])';
%                             obj.data.sumCounts(j,indices{:},:) = sum(dat);
%                             obj.data.stdCounts(j,indices{:},:) = std(dat);
%                         end
%                         obj.UpdateRun(status,managers,ax,j,indices{:});
%                     end
%                 end

                for freqIndex = 1:length(obj.scan_points)
                    obj.repumpLaser.on
                    obj.resLaser.TuneSetpoint(obj.scan_points(freqIndex));
                    obj.repumpLaser.off
                    
                    status.String = sprintf('Progress (%i/%i pts):\n  ', freqIndex, length(obj.scan_points));
                    
                    img = obj.imaging.snapImage;
                    
                    obj.data.images(:,:,freqIndex) = img;
                end

                obj.PostRun(status,managers,ax);

            catch err
            end
            
            if exist('err','var')
                rethrow(err)
            end
        end
        
        function PreRun(obj,~,managers,ax)
            %prepare frequencies
            obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            
            w = obj.imaging.width;
            h = obj.imaging.height;
            
            imagesc(1:w, 1:h, NaN(h, w));
            
            xlabel(ax, '$x$ [pix]', 'interpreter', 'latex');
            ylabel(ax, '$y$ [pix]', 'interpreter', 'latex');
            
            
            %prepare axes for plotting
%             hold(ax,'on');
%             %plot data
%             yyaxis(ax,'left');
%             colors = lines(2);
%             % plot signal
%             plotH{1} = errorfill(obj.scan_points,...
%                               obj.data.sumCounts(1,:,1),...
%                               obj.data.stdCounts(1,:,1),...
%                               'parent',ax,'color',colors(1,:));
%             ylabel(ax,'Intensity (a.u.)');
%             yyaxis(ax,'right');
%             plotH{2} = plot(ax,obj.scan_points,obj.data.freqs_measured(1,:),'color',colors(2,:));
%             ylabel(ax,'Measured Frequency (THz)');
%             xlabel(ax,obj.xlabel); %#ok<CPROPLC>
            
            % Store for UpdateRun
%             ax.UserData.plots = plotH;
%             hold(ax,'off');
%             set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
%         function UpdateRun(obj,~,~,ax,average,freqIndex)
%             %pull frequency that latest sequence was run at
%             obj.data.freqs_measured(average,freqIndex) = obj.resLaser.getFrequency;
%             
% %             if obj.averages > 1
% %                 averagedData = squeeze(nanmean(obj.data.sumCounts,3));
% %                 meanError = squeeze(nanmean(obj.data.stdCounts,3))*sqrt(obj.samples);
% %             else
% %                 averagedData = obj.data.sumCounts;
% %                 meanError = obj.data.stdCounts*sqrt(obj.samples);
% %             end
%             
%             %grab handles to data from axes plotted in PreRun
% %             ax.UserData.plots{1}.YData = averagedData(1,:);
% %             ax.UserData.plots{1}.YNegativeDelta = meanError(1,:);
% %             ax.UserData.plots{1}.YPositiveDelta = meanError(1,:);
% %             ax.UserData.plots{1}.update;
% %             ax.UserData.plots{2}.YData = nanmean(obj.data.freqs_measured,1);
% %             drawnow limitrate;
%         end
    end
end
