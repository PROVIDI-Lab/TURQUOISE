classdef BackupObj < handle
    
    properties (Access = public)
       imID,                %Image that was in focus
       imagePerAxis,        %Stores the images per view
       viewPerImage,
       slicePerImage,
       d4PerImage,          %4D index
       axID,                %Current uiAxes in focus
       cScalePerImage,      %contrast
       userObjects          %UserObjects
       
    end
    
    methods
        
    end
    
end