classdef BackupObj < handle
    
    properties (Access = public)
       current_image_idx,   %Image that was in focus
       imagePerAxis,        %Stores the images per view
       viewPerImage,
       slicePerImage,
       d4PerImage,          %4D index
       axID,        %Current uiAxes in focus
       MinValue,            %Minimum slider value
       MaxValue,            %Maximum slider value
       segmentation,        %User segmentations (sparse array)
       seg_prop,            %Segmentation properties
       seg_names,           %User segmentation names
       seg_shape,           %User segmentation size (= image size)
       measurements,        %User measurements
       measure_names        %User measurement names
       roiPoints,           %User segmentation points
       roiPointIndex,       %Segmentation index for the point
       userObjects          %UserObjects
       
    end
    
    methods
        
    end
    
end