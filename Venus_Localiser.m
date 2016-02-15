%
%
%
function Venus_Localiser(varargin)

% Declare the stimulus variable to be global
clear global stimulus;
global stimulus;

% Parse input parameters. Assign defaults to parameters that haven't been
% assigned through varargin
[success, stimulus] = parseArgs(varargin);
if ~success, ErrorBeep; disp('(Venus_Localiser) Cannot parse input arguments. Please check and re-run'); return; end;

% Initialise mGL
expScreen = initScreen(stimulus);

% Setup colors that will be used in the experiment
SetupColors(expScreen);

% first phase is just for having a start delay
task{1}.waitForBacktick = 0;
task{1}.seglen = [stimulus.run.startDelay 0.1];
task{1}.numTrials = 1;
task{1}.parameter.strength = 0;
task{1}.synchToVol = [0];

% Setup the fixation task
% set the first task to be the fixation staircase task
global fixStimulus;
% default values
fixStimulus.diskSize = 0.5;
fixStimulus.fixWidth = 2;
fixStimulus.fixLineWidth = 4;
fixStimulus.stimTime = 1;
fixStimulus.responseTime = 2;
fixStimulus.diskSize = 0;
% fixStimulus.pos = [xOffset yOffset];
[task{1} expScreen] = fixStairInitTask(expScreen);

% Setup the localiser task 
% The segments here are as follows: 
% 1. Stimulus presentation
% 2. Response
% 3. Feedback
% 4. ITI - inter trial interval
task{2}.waitForBacktick = 1;
task{2}.seglen = [12];
task{2}.synchToVol = [1];
task{2}.fudgeLastVolume = 1;
task{2}.randVars.calculated.side = nan;
% Setup drifting gratings
SetupGratingTextures(expScreen, task);

% Set the color of front and back buffers to background
mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;
mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;

% Initiliase the task
%[task{1} expScreen] = initTask(task{1},expScreen,@StartSegmentCallback,@UpdateScreenCallback,@ResponseCallback);
[task{2} expScreen] = initTask(task{2},expScreen,@StartSegmentCallback,@UpdateScreenCallback,@ResponseCallback);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% run the eye calibration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
expScreen = eyeCalibDisp(expScreen);

% Main display loop
phaseNum = 1;
while (phaseNum <= length(task{2})) && ~expScreen.userHitEsc
  % Update trial and stimulus parameters
  [task{2} expScreen phaseNum] = updateTask(cellArray(task{2}),expScreen,phaseNum);
  % update the fixation task
  [task{1} expScreen] = updateTask(task{1},expScreen,1);
  % flip screen
  expScreen = tickScreen(expScreen,task);
end

mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;
% End the experiment and save the results
expScreen = endTask(expScreen,task);


%*******************************************************
% function that gets called at the start of each segment
function [task myscreen] = StartSegmentCallback(task, myscreen)

global stimulus;
% The first task (task{1} is just a delay for the scanner. None of the code
% below will be executed and the screen will only show the background
% colour.
if task.taskID == 2 && task.thistrial.thisseg == 1
    if mod(task.trialnum, 2) == 1
        % Grating presented to the left
        task.thistrial.side = 1;
    else
        % Grating presented to the right
        coordinates = stimulus.run.rightVFCoord;
        task.thistrial.side = 2;
    end
end

% Display contrast intensity presented on this trial
% if task.taskID == 2 && task.thistrial.thisseg == 2
%     intensity = task.randVars.stimRandomOrder(task.trialnum, 1);
%     disp(sprintf('Contrast = %3.4f', stimulus.run.intensities(intensity)));
%     task.thistrial.contrast = stimulus.run.intensities(intensity);
%     visualField = task.randVars.stimRandomOrder(task.trialnum, 2);
%     %
%     if visualField == 1
%         task.thistrial.signedContrast = -stimulus.run.intensities(intensity);
%         task.thistrial.side = 1;
%         task.thistrial.signedSide = -1;
%     else
%         task.thistrial.signedContrast = stimulus.run.intensities(intensity);
%         task.thistrial.side = 2;
%         task.thistrial.signedSide = 1;
%     end
%     
% end

%*******************************************************
% Handles updating the screen during each frame refresh
function [task myscreen] = UpdateScreenCallback(task, myscreen)

global stimulus;
% Clear screen to background color
mglClearScreen(stimulus.colors.midGratingIndex);

% Present the stimulus
if task.taskID == 2 && task.thistrial.thisseg == 1
    SetGammaTableForMaxContrast(stimulus.run.intensities(1)); 
    % Present drifting grating on left or right depending on whether the
    % trialnum is odd or even
    %if task.trialnum 
    
    % Present a drifting grating either in the left or right visual field
    % The random order of the grating intensity, visual field and and drift
    % orientation is stored in task.randVars.stimRandomOrder. It is a
    % ntrials by 3 array, where first element is intensity, second visual
    % field and the third element determines the drift orientation

    if mod(task.trialnum, 2) == 1
        % Present grating to the left visual field
        coordinates = stimulus.run.leftVFCoord;
        %task.thistrial.side = 1;
    else
        % Present grating to the right visual field
        coordinates = stimulus.run.rightVFCoord;
        %task.thistrial.side = 2;
    end
    
    % For localizer we only use one intensity level, so let's set this to that index
    %intensity = stimulus.run.intensities(1);
    intensity = 1;
    drift = mod(floor(mglGetSecs(task.thistrial.segstart)), 2);
    
    % Compute which phase of the drifting grating to be displayed
    %gratingPhase = mglGetSecs(task.thistrial.segstart) /     
    thisPhase = floor(mglGetSecs(task.thistrial.segstart) / myscreen.frametime);
    % Ensure thisPhase doesn't go beyond precomputed number of
    % phase-shifted gratings
    if thisPhase < stimulus.grating.nPhaseShifts
        if drift == 1 % drift to the left
            gratingPhaseToShow = stimulus.grating.nPhaseShifts - thisPhase;
        else
            gratingPhaseToShow = stimulus.grating.nPhaseShifts + thisPhase;
        end
    % Texture to graphics card. When using 10 bit gamma, "intensity"
    % variable below has no meaning because all textures are generated to
    % be at the highest possible contrast. The contrast clamping occurs on
    % the gamma level with the SetGammaTableForMaxContrast function used
    % above
    mglBltTexture(stimulus.grating.textures{intensity, gratingPhaseToShow}, coordinates);
    % Draw two annuli in the left and right visual field where stimulus is presented to reduce spatial uncertainty
    % draw reference points
    % mglLines2(stimulus.grating.refLines.x1,stimulus.grating.refLines.y1,stimulus.grating.refLines.x2,stimulus.grating.refLines.y2,1,stimulus.colors.reservedColor(2));
    % mglLines2(-6*stimulus.grating.refLines.x1,stimulus.grating.refLines.y1,-6*stimulus.grating.refLines.x2,stimulus.grating.refLines.y2,1,stimulus.colors.reservedColor(2));
    
    %mglGluAnnulus(stimulus.run.leftVFCoord(1), stimulus.run.leftVFCoord(2), 3.5, 3.54, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
    %mglGluAnnulus(stimulus.run.rightVFCoord(1), stimulus.run.rightVFCoord(2), 3.5, 3.54, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
    
    annulusRadius = stimulus.grating.width / 2; % Get the radius of stimulus and make it a little bigger so that Gabor is comfortably displayed inside
    mglGluAnnulus(stimulus.run.leftVFCoord(1), stimulus.run.leftVFCoord(2), annulusRadius, annulusRadius+0.04, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
    mglGluAnnulus(stimulus.run.rightVFCoord(1), stimulus.run.rightVFCoord(2), annulusRadius, annulusRadius+0.04, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);

    end
    % disp(sprintf('(Venus_RunExperiment) grating display for trial number %i', task.trialnum));
end


%*******************************************************
% Setup color range used in the experiment
function SetupColors(expScreen)

global stimulus;
% set maximum color index (for 24 bit color we have 8 bits per channel, so 255)
maxIndex = 255;
% get gamma table
if ~isfield(expScreen,'gammaTable')
  stimulus.linearizedGammaTable = mglGetGammaTable;
  disp(sprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'));
  disp(sprintf('(taskTemplateContrast10bit:initGratings) No gamma table found in myscreen. Contrast'));
  disp(sprintf('         displays like this should be run with a valid calibration made by moncalib'));
  disp(sprintf('         for this monitor.'));
  disp(sprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'));
end
stimulus.linearizedGammaTable = expScreen.initScreenGammaTable;
% these are the reserved colors, if you need them later
% you can display them by setting your color to the appropriate
% index in stimulus.colors.reservedColor e.g. to get the
% second color, in this case white, you would do
% mglClearScreen(stimulus.colors.reservedColor(2));
stimulus.colors.reservedColors = [0 0 0; 1 1 1; 0 1 1; 1 0 0; 0 1 0];
% calculate some colors information
%  number of reserved colors
stimulus.colors.nReservedColors = size(stimulus.colors.reservedColors,1);
% number of colors possible for gratings, make sure that we
% have an odd number
stimulus.colors.nGratingColors = maxIndex+1-stimulus.colors.nReservedColors;
if iseven(stimulus.colors.nGratingColors)
    stimulus.colors.nGratingColors = stimulus.colors.nGratingColors-1;
end
% min, mid and max index of gratings colors (index values are 0 based)
stimulus.colors.minGratingIndex = maxIndex+1-stimulus.colors.nGratingColors;
stimulus.colors.midGratingIndex = stimulus.colors.minGratingIndex+floor(stimulus.colors.nGratingColors/2);
stimulus.colors.maxGratingIndex = maxIndex;
% number of contrasts we can display (not including 0 contrast)
stimulus.colors.nDisplayContrasts = floor(stimulus.colors.nGratingColors/2);
% get the color value for gray (i.e. the number between 0 and 1 that corresponds to the midGratingIndex)
stimulus.colors.grayColor = stimulus.colors.midGratingIndex/maxIndex;
% set the reserved colors - this gives a convenient value between 0 and 1 to use the reserved colors with
for i = 1:stimulus.colors.nReservedColors
    stimulus.colors.reservedColor(i) = (i-1)/maxIndex;
end



%*********************************************************
% Generate textures for gratings of different intensities
% as welll as surrogate textures to generate leftward and 
% rightward drifts
function SetupGratingTextures(expScreen, task)

%%%%% ***** NOTE *****
% This function generates a multiple of textures as it is a legacy code
% which had to generate textures of different contrast intensities. After
% implement 10 bit gamma table, all textures are generated at the 
% maximum intensity and only the gamma table is adjusted to have a maximum
% level as per requested contrast intensity
global stimulus;
disppercent(-inf,'Creating grating textures');
% Phase shift step size to achieve requested temporal frequency
stimulus.grating.phaseShiftPerFrame = 360 * stimulus.grating.temporalFrequency / expScreen.framesPerSecond;
% Total number of phase shifts to fit into stimulus duration 
stimulus.grating.nPhaseShifts = round(task{2}.seglen / expScreen.frametime);
% stimulus.grating.phaseStep = stimulus.grating.totalPhaseShift / (stimulus.grating.nPhaseShifts - 1);
% Prepare grating textures for intensities that will be presented. Make it
% twice longer so that the grating can move to both left and right
gratingTextures = cellArray(stimulus.run.intensities, 2 * stimulus.grating.nPhaseShifts - 1);
% Prepare grating texture for all intensities
for ixGrating = 1:stimulus.run.nIntensities
    for ixPhase = 1:stimulus.grating.nPhaseShifts * 2 - 1;
        grating = mglMakeGrating(stimulus.grating.width, ...
            stimulus.grating.height, ...
            stimulus.grating.spatialFrequency, ...
            stimulus.grating.orientation, ...
            stimulus.grating.phase - (ixPhase - stimulus.grating.nPhaseShifts) * stimulus.grating.phaseShiftPerFrame);
        gaussianSD = stimulus.grating.width/6;  % A simple approch to adjusting the width of the gaussian 
        gaussian = mglMakeGaussian(stimulus.grating.height, stimulus.grating.width, gaussianSD, gaussianSD);
        % Apply either gabor window or a circular window
        if strcmp(stimulus.grating.gratingWindowType,'gabor')
            % a gaussian window
            win = gaussian;
        else
            % a simple window limited to 1 standard deviation of Gaussian
            win = gaussian > exp(-1/2);
        end
        gabor = grating.*win;
        % keyboard;
        % Make grating backgound to match the background colour and apply contrast (contrast is not applied, but gamma table is altered elsewhere)       
        gabor = stimulus.colors.midGratingIndex + round(stimulus.colors.nDisplayContrasts .* gabor); 
        gratingTextures{ixGrating, ixPhase} = mglCreateTexture(gabor);
    end
    %     % For debugging purposes, display leftward drifting Gabor
    %     for ixPhase = 1:stimulus.grating.nPhaseShifts
    %         mglBltTexture(gratingTextures{ixGrating, stimulus.grating.nPhaseShifts - ixPhase + 1}, [6 6]);
    %         mglFlush;
    %         stimulus.grating.nPhaseShifts - ixPhase + 1
    %     end
    %     % For debugging purposes, display rightward drifting Gabor
    %     for ixPhase = 1:stimulus.grating.nPhaseShifts
    %         mglBltTexture(gratingTextures{ixGrating, stimulus.grating.nPhaseShifts + ixPhase - 1}, [6 6]);
    %         mglFlush;
    %     end
    disppercent(ixGrating/stimulus.run.nIntensities);
end
% save in "stimulus" global variable
stimulus.grating.textures = gratingTextures;
disppercent(Inf);

% set up reference lines
stimulus.grating.refLines.x1 = [];
stimulus.grating.refLines.y1 = [];
stimulus.grating.refLines.x2 = [];
stimulus.grating.refLines.y2 = [];
% Setup circular rings where stimulus to be presented
centerX = stimulus.grating.radius*cos(pi/180);
centerY = stimulus.grating.radius*sin(pi/180);
% get radius
radius = sqrt(((stimulus.grating.width/2)^2)+((stimulus.grating.height/2)^2))-0.5;
% get left/right top/bottom;
left = centerX-stimulus.grating.width/2;
right = centerX+stimulus.grating.width/2;
top = centerY-stimulus.grating.height/2;
bottom = centerY+stimulus.grating.height/2;
% circular reference lines
d = 0:1:360;
for dIndex = 1:length(d)-1
    stimulus.grating.refLines.x1 = [stimulus.grating.refLines.x1 centerX+radius*cos(d2r(d(dIndex)))];
    stimulus.grating.refLines.y1 = [stimulus.grating.refLines.y1 centerY+radius*sin(d2r(d(dIndex)))];
    stimulus.grating.refLines.x2 = [stimulus.grating.refLines.x2 centerX+radius*cos(d2r(d(dIndex+1)))];
    stimulus.grating.refLines.y2 = [stimulus.grating.refLines.y2 centerY+radius*sin(d2r(d(dIndex+1)))];
end


%**********************************************************************************
% Sets the gamma table so that we can have
% finest possible control over the stimulus contrast.
%
% stimulus.reservedColors should be set to the reserved colors (for cue colors, etc).
% maxContrast is the maximum contrast you want to be able to display.
function SetGammaTableForMaxContrast(maxContrast)

global stimulus;
% if you just want to show gray, that's ok, but to make the
% code work properly we act as if you want to display a range of contrasts
if maxContrast <= 0,maxContrast = 0.01;end
% set the reserved colors
gammaTable(1:size(stimulus.colors.reservedColors,1),1:size(stimulus.colors.reservedColors,2))=stimulus.colors.reservedColors;
% set the gamma table
if maxContrast > 0
  % create the rest of the gamma table
  cmax = 0.5+maxContrast/2;cmin = 0.5-maxContrast/2;
  luminanceVals = cmin:((cmax-cmin)/(stimulus.colors.nGratingColors-1)):cmax;
  % now get the linearized range
  redLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.redTable,luminanceVals,'linear');
  greenLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.greenTable,luminanceVals,'linear');
  blueLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.blueTable,luminanceVals,'linear');
  % add these values to the table
  gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,:)=[redLinearized;greenLinearized;blueLinearized]';
else
  % if we are asked for 0 contrast then simply set all the values to gray
  gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,1)=interp1(0:1/255:1,stimulus.linearizedGammaTable.redTable,0.5,'linear');
  gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,2)=interp1(0:1/255:1,stimulus.linearizedGammaTable.greenTable,0.5,'linear');
  gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,3)=interp1(0:1/255:1,stimulus.linearizedGammaTable.blueTable,0.5,'linear');
end
% set the gamma table
mglSetGammaTable(gammaTable);


% ********************************************
% parseArgs
function [success, stimulus] = parseArgs(args)

success = 1;
% Set arguments based on passed parameters. The rest will be set to defaults.
getArgs(args,{ ...
    'subjectID=TempSubjectVenus'...                % Default subject name
    'width=6', ...                          % grating width in degrees of visual angle
    'height=6', ...                         % grating height in degrees of visual angle
    'orientation=90', ...                   % grating orientation
    'spatialFrequency=1', ...               % grating spatial frequency in cycles per pixel
    'temporalFrequency=0.5', ...            % temporal frequency of the grating
    'phase=0', ...                          % grating's sinewave phase
    'gratingWindowType=gabor', ...          % Can be either gabor or threshold
    'radius=6', ...                         % Grating radius. Currently unused
    'leftVFCoord=[-9 0]',...                % Position of the stimulus in the left visual field
    'rightVFCoord=[9 0]', ...               % Position of the stimulus in the right visual field
    'intensities=[1.0]', ...             	% contrast intensities to test. It is 100% contrast for the localiser scan
    'nIntensities=[]', ...                  % Number of intensities
    'trialsPerIntensity=22', ...             % stim repetitions per contrast. SHOULD BE EVEN NUMBER
    'numTrials=[]'...                         % Total number of trials
    'feedback=1'...                         % feedback to participant
    'soundStim=~/proj/grustim/sounds'...    % where feedback sounds are
    'correctSound=Pop'...                   % Sound feedback to correct responses
    'incorrectSound=Basso'...               % Sound feedback to incorrect responses
    'waitForBacktick=0' ...                 % Parameter used for scanner
    'scanner=1'...                          % Are we in the scanner?
    'startDelay=[]'
    });

% Subject parameters
stimulus.subjectID = subjectID;
% Grating parameters
stimulus.grating.width = width;
stimulus.grating.height = height;
stimulus.grating.orientation = orientation;
stimulus.grating.spatialFrequency = spatialFrequency;
stimulus.grating.temporalFrequency = temporalFrequency;
stimulus.grating.phase = phase;
stimulus.grating.radius = radius;
%keyboard;
stimulus.grating.gratingWindowType = gratingWindowType;
% Set the startDelay duration depending we are in scanner or not
if scanner
    if isempty(waitForBacktick),waitForBacktick = 1;end
    if isempty(startDelay),startDelay = 5;end
else
    if isempty(waitForBacktick),waitForBacktick = 0;end
    if isempty(startDelay),startDelay = 5;end
end
% Set run parameters
stimulus.run.intensities = intensities;
stimulus.run.nIntensities = length(intensities);
%stimulus.run.trialsPerIntensity = trialsPerIntensity;
%stimulus.run.nTrials = length(intensities) * trialsPerIntensity;
stimulus.run.feedback = feedback;
stimulus.run.soundStim = soundStim;
stimulus.run.correctSound = correctSound;
stimulus.run.incorrectSound = incorrectSound;
stimulus.run.scanner = scanner;
stimulus.run.waitForBacktick = waitForBacktick;
stimulus.run.startDelay = startDelay;
stimulus.run.leftVFCoord = leftVFCoord;
stimulus.run.rightVFCoord = rightVFCoord;

