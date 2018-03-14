function rootPath=rigRootPath()
% Return the path to the root iset directory
%
% This function must reside in the directory at the base of the
% 360CameraSimulation. directory structure.  It is used to determine the
% location of various sub-directories.
% 
% Example:
%   fullfile(rigRootPath,'data')

rootPath=which('rigRootPath');

[rootPath,fName,ext]=fileparts(rootPath);

return
end
