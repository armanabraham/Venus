function Venus_Mat2Txt(varargin)
% Convert requested sessions (runs) from MAT to TXT format for further processing in R
% Example: Venus_Mat2Txt('sessions=[1 2 3]', 'subjectID=IMJ', 'overwrite=yes')

if isempty(varargin) 
	help Venus_Mat2Txt;
	return;
end

[params] = parseArgs(varargin);

if isempty(params.sessions)
    disp(sprintf('(Venus_Mat2Txt) Please specify sessions'));
    return;
end

if isempty(params.subjectID)
    disp(sprintf('(Venus_Mat2Txt) Please specify subjectID'));
    return;
end

if isempty(params.overwrite)
    disp(sprintf('(Venus_Mat2Txt) "overwrite" is set to NO'));
 	params.overwrite = 'No';
 end

% Prepare file name templates based on session number to search for the sessio file
sessionNumbers = regexp(sprintf('%i ',params.sessions),'(\d+)','match');
filesToSearch = strcat({'*session'}, sessionNumbers, '.mat');
filesToConvert = cell(0);
sessionsToConvert = cell(0);
for ixSession=1:length(filesToSearch)
	% See if a file with the provided session number exists in the current directory
	thisSessionFile = dir(fullfile(filesToSearch{ixSession}));
	%keyboard;
    % Check if a file with the requested session number exist
	if (~isempty(thisSessionFile)) 
		% Add name of the file that corresponds to the session to cell array
		filesToConvert = [filesToConvert thisSessionFile.name];
		sessionsToConvert = [sessionsToConvert sessionNumbers{ixSession}];
	else 
		disp(sprintf('(Venus_Mat2Txt) WARNING: Session number - %s - does not exist', sessionNumbers{ixSession}));
	    %disp(sprintf('(getContrastIndex) Desired contrast: %0.4f Actual contrast: %0.4f Difference: %0.4f',desiredContrast,actualContrast,desiredContrast-actualContrast));
	end
	%keyboard;
end
disp(sprintf('(Venus_Mat2Txt) Following MAT files will be used to generate TXT files:'));
disp(filesToConvert(:));


% Check if ovewrite parameter is set to Yes or No. 
% If Yes, delete all TXT files that exist to they can be 
% recreated
if strcmp(lower(params.overwrite), 'yes')
	disp(sprintf('(Venus_Mat2Txt) Existing TXT files will be overwritten as requested'));
	for ixFileToProcess = 1:length(filesToConvert)
		textFileName = strrep(filesToConvert{ixFileToProcess}, '.mat', '.txt');
		fullFileName = [pwd '/' textFileName];
		if exist(fullFileName) 
			disp(sprintf('(Venus_Mat2Txt) Deleting existing file: %s', fullFileName));
			delete(fullFileName);
		end
	end	
end

% Start converting
subjectIDParam = ['subjectID=', params.subjectID];
for ixFileToProcess = 1:length(filesToConvert)
	fileNameParam = ['matFileName=', pwd '/' filesToConvert{ixFileToProcess}];
	sessionNumberParam = ['sessionNumber=', sessionsToConvert{ixFileToProcess}];
	Venus_DataToR_v3(fileNameParam, subjectIDParam, sessionNumberParam)
end
%keyboard;

%********************************************
% parseArgs
function [params] = parseArgs(args)

success = 1;
% Set arguments based on passed parameters. The rest will be set to defaults. 
getArgs(args,{ ...
    'sessions=[]',...                   	% Name of the data file
    'subjectID=IMJ', ...                	% Subject ID
    'overwrite=No'	                		% When set to No, does not overwrite existing TXT files
    });
% Pack all arguments into a structure            
params.sessions = sessions; 
params.subjectID = subjectID; 
params.overwrite = overwrite;
% keyboard;
