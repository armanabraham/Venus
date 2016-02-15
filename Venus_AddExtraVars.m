% Venus_AddExtraVars
% 
%      usage: Venus_AddExtraVars(stimFileName)
%         by: arman abrahamyan
%       date: 03/09/12
%    purpose: add new variables, such as previousSuccsess/prevFailure, for
%    fMRI data analysis. Parts adapted from Justin's addCalculatedVar
%    function
% 
%       e.g.: Venus_AddExtraVars('120817_stim01.mat')
%
function success = Venus_AddExtraVars(stimFileName)

% check arguments
if any(nargin < 1)
  help Venus_AddExtraVars
  return
end
% Append extension, if necessary, and check if stim file exists
stimFileName = setext(stimFileName,'mat');
if ~isfile(stimFileName) 
  disp(sprintf('(Venus_AddExtraVars) Could not find stimfile %s', stimFileName));
  return
end
% Load stim file and validate
global stim;
stim = load(stimFileName);
if ~isfield(stim,'myscreen') || ~isfield(stim,'task')
  disp(sprintf('(Venus_AddExtraVars) File %s is not a stimfile - missing myscreen or task', stimFileName));
  return
end

% Extract task parameters
vars = getTaskParameters(stim.myscreen, stim.task);
vars = cell2mat(vars);
stim.task = cellArray(stim.task,2);
% Number of trials in the experiment
nTrials = vars(2).nTrials;
%%% prevFailureSuccess=zeros(1,nTrials);

contrast.intensity = sort(unique(vars(2).randVars.contrast));
contrast.labels = strcat(repmat('c',length(contrast.intensity),1), strtrim(cellstr(num2str(contrast.intensity'))))';
contrast.labels = strrep(contrast.labels, '.', '_');
% Create variables that match each contrast intensity. 
% Trials are coded as -1 if contrast is presented on left, and +1 if
% contrast is presented on right
for ixContrast = 1:length(contrast.intensity)
    contrast.matrix{ixContrast} = zeros(1, nTrials);
    contrastTrialsLeft = (vars(2).randVars.contrast==contrast.intensity(ixContrast)) & (vars(2).randVars.side ==1);
    contrastTrialsRight = (vars(2).randVars.contrast==contrast.intensity(ixContrast)) & (vars(2).randVars.side ==2);
    contrast.matrix{ixContrast}(contrastTrialsLeft) = -1;    
    contrast.matrix{ixContrast}(contrastTrialsRight) = 1;
    % Add new variable
    AddNewVar(contrast.labels{ixContrast}, contrast.matrix{ixContrast});
   
%     stim.task{1}{2}.randVars.n_ = stim.task{1}{2}.randVars.n_+1;
%     stim.task{1}{2}.randVars.names_{end+1} = contrast.labels{ixContrast};
%     stim.task{1}{2}.randVars.varlen_(end+1) = length(contrast.matrix{ixContrast});
%     varname = contrast.labels{ixContrast};
%     stim.task{1}{2}.randVars.(varname) = contrast.matrix{ixContrast};
%     % add it to calculated
%     stim.task{1}{2}.randVars.calculated.(varname) = unique(contrast.matrix{ixContrast});
end

% Add history variables, when subjects succeeded or failed on previous trial
prevCorr = zeros(1, nTrials);
prevFail = zeros(1, nTrials); 
for ixTrial = 2:nTrials
    % if no response, both history terms remain 0
    if ~isnan(vars(2).response(ixTrial-1)) 
        % Check if previous trial was success
        if vars(2).response(ixTrial-1) == vars(2).randVars.side(ixTrial-1)
            prevCorr(ixTrial) = vars(2).response(ixTrial-1);
        else
            % when previous response was wrong
            prevFail(ixTrial) = vars(2).response(ixTrial-1);
        end
    end
end
% Changing coding so left side is coded -1 and right side +1
prevCorr(prevCorr==1) = -1; prevCorr(prevCorr==2) = 1;
prevFail(prevFail==1) = -1; prevFail(prevFail==2) = 1;
% add history variables
AddNewVar('prevCorr', prevCorr);
AddNewVar('prevFail', prevFail);

% Start checking if previous trial was success or failure, starting from trial #2
% Here we sort trials into previous success and previous fail, without caring about 
% left or right side
for ixTrial = 2:nTrials
  if isnan(vars(2).response(ixTrial-1))
    prevFailureSuccess(ixTrial) = 0;
  elseif vars(2).response(ixTrial-1) == vars(2).randVars.side(ixTrial-1)
    % When response on prev trial was success, code this as "2"
    prevFailureSuccess(ixTrial) = 2;
  else
    % When response on prev trial was incorrect, code this as "1"
    prevFailureSuccess(ixTrial) = 1;
  end
  
end
%Add the new variable to the stim file
AddNewVar('prevFailureOrSuccess', prevFailureSuccess);

%% Variable that defines whether curent trials is fail or success
for ixTrial = 1:nTrials
  if isnan(vars(2).response(ixTrial))
    currentFailOrSuccess(ixTrial) = 0;
  elseif vars(2).response(ixTrial) == vars(2).randVars.side(ixTrial)
    % When response on this trial was success, code this as "2"
    currentFailOrSuccess(ixTrial) = 2;
  else
    % When response on this trial was incorrect, code this as "1"
    currentFailOrSuccess(ixTrial) = 1;
  end
end
AddNewVar('currentFailOrSuccess', currentFailOrSuccess);



% now make sure there is an original backup
originalBackup = sprintf('%s_original.mat',stripext(stimFileName));
if isfile(originalBackup)
    originalBackup = sprintf('%s_backup_%s.mat',stripext(stimFileName),datestr(now,'ddmmyyyy_HHMMSS'));
    disp(sprintf('(Venus_AddExtraVars) Original backup already exists, saving as %s',originalBackup));
end
if isfile(originalBackup)
    disp(sprintf('(Venus_AddExtraVars) %s already exists',originalBackup));
else
    % save
    eval(sprintf('save %s -struct stim',originalBackup));
end
% and save
%disp(sprintf('(addCalculatedVar) Saving variable %s into %s for taskNum=%i phaseNum=%i',varname,stimfile,taskNum,phaseNum));
eval(sprintf('save %s -struct stim',stimFileName));

end % Function AddExtraVars 

function succes = AddNewVar(varName, varVal)
  global stim; 
  stim.task{1}{2}.randVars.n_ = stim.task{1}{2}.randVars.n_+1;
  stim.task{1}{2}.randVars.names_{end+1} = varName;
  stim.task{1}{2}.randVars.varlen_(end+1) = length(varVal);
  stim.task{1}{2}.randVars.(varName) = varVal;
  % add it to calculated
  stim.task{1}{2}.randVars.calculated.(varName) = unique(varVal);
end % Function AddNewVar


