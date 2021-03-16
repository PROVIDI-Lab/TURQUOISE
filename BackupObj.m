classdef BackupObj < handle
    
    properties (Access = public)
       current_image_idx,   %Image that was in focus
       image_per_view,      %Stores the images per view
       current_4d_idx,      %4D index
       view_axis,           %Coronal, Sagittal, Axial (=1,2,3,)
       current_view,        %View that was in focus
       current_slice,       %Slice that was beeing looked at
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