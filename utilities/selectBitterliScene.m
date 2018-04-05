function [pbrtFile,rigOrigin] = selectBitterliScene(sceneName)
%SELECTBITTERLISCENE Keep track of PBRT scene file locations and good 360
%rig locations here. These scenes are all from Benedikt Bitterli
%(https://benedikt-bitterli.me/resources/) but modified to include more
%lights and to be compatible with the pbrt2ISET parser. The rig origin
%locations were chosen manually; they are near the center of
%the room at roughly 5-6 ft above the ground.

% We will use the remote data toolbox to download the scenes into your
% piRootPath/data folder. If the scenes already exist, the download should
% skip. 
sceneDir = fullfile(piRootPath,'data');


switch sceneName
    case('whiteRoom')
        sceneName = 'white-room';
        rigOrigin = [0.9476 1.3018 3.4785] + [0 0.600 0];
        
    case('livingRoom')
        sceneName = 'living-room';
        rigOrigin = [2.7007    1.5571   -1.6591];
        
    case('bathroom')
        rigOrigin = [0.3   1.667   -1.5];
        
    case('kitchen')
        rigOrigin = [0.1768    1.7000   -0.2107];
        
    case('bathroom2')
        rigOrigin = [];
        
    case('bedroom')
        rigOrigin = [1.1854    1.1615    1.3385];
        
    otherwise
        error('Scene not recognized.');
end

% If file does not already exist, download it.
pbrtFile = fullfile(sceneDir,sceneName,'scene.pbrt');
if(~exist(pbrtFile,'file'))
    piPBRTFetch(sceneName,'deletezip',true);
    % Check if file exists
    if(~exist(pbrtFile,'file'))
        error('Something went wrong when downloading the scene.')
    else
        % Success!
        fprintf('PBRT scene downloaded! File is located at: %s \n',pbrtFile);
    end
 
else
    fprintf('Scene already exists in data folder. Skipping download.\n');
end

if(isempty(rigOrigin))
    warning('Rig origin not set for this scene yet.')
end


end

