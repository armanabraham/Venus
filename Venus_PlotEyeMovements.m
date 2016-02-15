% Read stim file and eye movement data
% Eye traces are loaded from segment 1
cd ~/proj/arman/Venus/DataCollection/s001
stimAndEyeData = getTaskEyeTraces('130910_stim01_session53', 'dispFig=0', 'removeBlink=1', 'phaseNum=2', 'segNum=1');

% For reproducibility, set randon generator seed to mySeed
mySeed = 10;
rng(mySeed);

% Randomly pick a few trials to examine 
nTracesToExamine = 5;
ixTracesToExamine = round(rand(1, nTracesToExamine) * stimAndEyeData.nTrials);
%ixTracesToExamine = 1:299; % To plot all traces
trialsToExamine = stimAndEyeData.trials(ixTracesToExamine);
eyeData.xPos = stimAndEyeData.eye.xPos(ixTracesToExamine, :); 
eyeData.yPos = stimAndEyeData.eye.xPos(ixTracesToExamine, :); 
eyeData.time = stimAndEyeData.eye.time; % Time is one dimensional

% Use color brewer for plotting
brewerColors=cbrewer('qual', 'Set1', nTracesToExamine);
set(0,'DefaultAxesColorOrder', brewerColors);

% First subplot shows data sarting from segment 1
figure;
subplot(1, 3, 1);
plot(eyeData.time, eyeData.xPos, 'LineSmoothing','off', 'LineWidth', 4); 
hold on;

% Find the beginning of the second segment for each trace
secondSegStartTimes = [];
ixSecondSegStart = [];
for ixTrace=1:nTracesToExamine
	% Subtract start of first segment from start of second segment to align traces to the beginning of each trial
	secondSegStartTimes = [secondSegStartTimes trialsToExamine(ixTrace).segtime(2) - trialsToExamine(ixTrace).segtime(1)]; 
	[minVal, ixStart] = min(abs(eyeData.time - secondSegStartTimes(ixTrace)));
	ixSecondSegStart = [ixSecondSegStart ixStart];
end

% Plot traces from segment 1 to segment 3, and highlight parts that belong to segment 2
for ixTrace = 1:nTracesToExamine
	subplot(1, 3, 2);
	plot(eyeData.time(ixSecondSegStart(ixTrace):end), eyeData.xPos(ixTrace, ixSecondSegStart(ixTrace):end), 'LineWidth', 3, 'Color', [249/256 201/256 9/256]);
	hold on;
	subplot(1, 3, 1);
	plot(eyeData.time(ixSecondSegStart(ixTrace):end), eyeData.xPos(ixTrace, ixSecondSegStart(ixTrace):end), 'LineWidth', 1, 'Color', 'Yellow');
	hold on;
end

% ---- Load the same eye traces again, but this time 
% use segNum=2, to compare with results of segNum=1 
stimAndEyeDataSeg2 = getTaskEyeTraces('130910_stim01_session53', 'dispFig=0', 'removeBlink=1', 'phaseNum=2', 'segNum=2');
eyeData2.xPos = stimAndEyeDataSeg2.eye.xPos(ixTracesToExamine, :); 
eyeData2.yPos = stimAndEyeDataSeg2.eye.xPos(ixTracesToExamine, :); 
eyeData2.time = stimAndEyeDataSeg2.eye.time; % Eye movements time is one dimensional
subplot(1, 3, 3);
plot(eyeData2.time, eyeData2.xPos, 'LineSmoothing','off', 'LineWidth', 4); 

% Make axes on all plots to be the same 
xMin = 0; xMax = 3.0;
subplotTitle{1} = {'Plot 1: Traces using parameter "segNum=1"', 'Yellow parts show data starting from seg 2'};
subplotTitle{2} = {'Plot 2: Traces using parameter "segNum=1"', 'Plot from segment 2 (same as yellow in Plot 1)'};
subplotTitle{3} = {'Plot 3: Traces using parameter "segNum=2"', 'These traces match the shape of traces in middle plot'};
for ixSubplot=1:3 
	subplot(1, 3, ixSubplot);
	xlim([xMin, xMax]);
	ylim([min(min(eyeData.xPos)), max(max(eyeData.xPos))]);
	title(subplotTitle{ixSubplot}, 'FontSize', 15, 'FontWeight', 'bold');
	%drawPublishAxis;
end

