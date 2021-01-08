classdef Study < handle
    %This static class deals with all functions that specifically change
    %the variables related to the currently loaded study.
    %These include:
    %   app.measurement_list
    methods (Static)
        
        function InitStudy(app)
            %Initialises all objects that are used when working with a
            %study. Called after PrepareStudy.
            
            nImages     = length(app.AvailableimagesListBox.Items);
            
            app.segmentation_list   = {};
            app.seg_names_list      = {};
            app.measurement_list    = {};    
            app.measure_names_list  = {};
            app.measure_length_list = {};
            app.roiPointList        = {};
            app.roiPointIndexList   = {};
            
            app.segmentation        = [];
            app.seg_names           = [];
            app.measure_names       = [];
            app.slice_per_image     = num2cell(ones(1,nImages)*-1);
            %... add more objects
            
            app.drawing.points              = [];
            app.drawing.measurement_lines   = [];
            
            if isempty(app.user_profile)
                app.user_profile = {''};
            end
            
            %Load all user objects from disk
            for idx = 1:nImages
                Study.LoadFromDisk(app, idx)
            end
            
            %Initialize the window
            GUI.InitGUI(app)
            
        end
        
        
        function LoadFromDisk(app, index)
        %Load the image, segmentation and any measurements from disk when
        %it hasn't already been loaded.
        %Input: index - index of the image in AvailableImageListBox
       
            fp = app.current_folder;
            fn = app.AvailableimagesListBox.Items{index};
            app.current_image_idx   = index;
            try                  

                %Load existing segmentations
                %TODO split into different function
                segname = fullfile(fp, [fn(1:end-4)                     ...
                                       app.user_profile{1}              ...
                                       '-segmentation.nii']);
                IOUtils.LoadSegmentation(app, segname);
                
                pointfn = fullfile(fp, [fn(1:end-4)                    ...
                                         app.user_profile{1}            ...
                                         '-segmentation.json']);
                IOUtils.loadSegmentationPoints(app, pointfn);

                %Load existing measurements
                msr_name = fullfile(fp, [fn(1:end-4)                    ...
                                        app.user_profile{1}             ...
                                        '-measurements.csv']);
                IOUtils.LoadMeasurements(app, msr_name)

            catch 
                GUI.DisplayError(app)
            end
        end
        
        
        function LoadFromList(app, index)
            %Add all previously loaded objects from the list to the current
            %working environment.
             
            %Image
            IOUtils.LoadNii(app, index);
            
            %Segmentations
            if(~(index>length(app.segmentation_list)))
                if(~isempty(app.segmentation_list{index}))
                    app.segmentation    = app.segmentation_list{index};
                    app.seg_names       = app.seg_names_list{index};
                    ROI.UpdateSegmentationProperties(app);
                    
                    if ~isempty(app.roiPointList)
                        app.roiPoints       = app.roiPointList{index};
                        app.roiPointIndex   = app.roiPointIndexList{index};
                    else
                        app.roiPoints       = [];
                        app.roiPointIndex   = [];
                    end
                else
                    app.segmentation    = [];
                    app.seg_names       = {};
                    app.roiPoints       = [];
                    app.roiPointIndex   = [];
                end
            end

            %Measurements
            if(~(index>length(app.measurement_list)))
                if(~isempty(app.measurement_list{index}))
                    app.drawing.measurement_lines =                 ...
                                app.measurement_list{index};
                    app.measure_names = app.measure_names_list{index};
                    app.measure_length= app.measure_length_list{index};
                    
                else
                    app.drawing.measurement_lines   = [];
                    app.measure_names               = {};
                    app.measure_length              = [];
                end
            end

%             app.bkseg           = [];
            Graphics.DeleteAllDrawingPoints(app);

        end            
        
        function SaveToDisk(app)
            %Saves the current study to the .rmsstudio folder. All the 
            %User-made objects are written to either .nii or .csv files.
            
            
            %First save the most recent changes to the list
            Study.SaveToList(app)
            
            
            for image_id=1:length(app.segmentation_list)
                fn      = app.AvailableimagesListBox.Items{image_id};
                
                %Save the segmentation & its properties
                nii     = app.segmentation_list{image_id};
                points  = app.roiPointList{image_id};
                pointIdx= app.roiPointIndexList{image_id};
                
                if isfield(nii, 'img') &&                               ...
                   isfield(nii, 'hdr') &&                               ...
                   isfield(nii, 'properties')
                    
                    segfn   = fullfile(app.current_folder,              ...
                                        [fn(1:end-4)                    ...
                                         app.user_profile{1}            ...
                                         '-segmentation.nii']);
                    propfn  = fullfile(app.current_folder,              ...
                                        [fn(1:end-4)                    ...
                                         app.user_profile{1}            ...
                                         '-segmentation.csv']);
                                     
                    IOUtils.saveSegmentations(nii, segfn);
                    IOUtils.saveSegmentationProperties(nii, propfn);
                    
                end
                
                %Save segmentation points
                if ~isempty(points)
                    pointfn = fullfile(app.current_folder,              ...
                                        [fn(1:end-4)                    ...
                                         app.user_profile{1}            ...
                                         '-segmentation.json']);
                    IOUtils.saveSegmentationPoints(                     ...
                                            points, pointIdx, pointfn)
                end
                
                
                %Save measurements to .csv
                C       = app.measurement_list{image_id};
                if(~isempty(C))
                    IOUtils.saveMeasurementProperties(app, image_id);
                end
            end
        end
        
        function SaveToList(app)
            %Writes all the user objects to their respective lists so that
            %they can be loaded when the user switches back to that image.
            
            idx = app.current_image_idx;
            
            %Segmentation
            app.segmentation_list{idx}  = app.segmentation;
            app.seg_names_list{idx}     = app.seg_names;
            app.roiPointList{idx}       = app.roiPoints;
            app.roiPointIndexList{idx}  = app.roiPointIndex;
            
            
            if isfield(app.drawing, 'measurement_lines')
                %Measurements
                app.measurement_list{idx}   =                       ...
                                app.drawing.measurement_lines;
                app.measure_names_list{idx} = app.measure_names;
                app.measure_length_list{idx}= app.measure_length;
            end
        end
        
        function SwitchImage(app, index)
        % Switches workspace and display to a different image.
        % Input:
        %   app, reference to the RMSStudio app
        %   index, index of image in the available_image_box
            GUI.DisableControlsStatus(app);
            pause(0.01);
            drawnow            
            
            %Save all current user objects back to the list
            Study.SaveToList(app)
            %Store current image slice
            app.slice_per_image{app.current_image_idx} = app.current_slice;
            
            
            %Switch to new image
            app.current_image_idx = index;
            app.current_slice   = app.slice_per_image{index};
            
            %Load the image, segmentations and measurement into the study,
            %either from disk, or from the list.
%             Study.LoadFromDisk(app, index)
            Study.LoadFromList(app, index)
            
            %Show everything
            GUI.DisplayNewImage(app, index)
            
            %Keep track of which image is in which view
            app.image_per_view(app.current_view) = index;
        end
               
        
        function delObj = FindObjectTypeAtPos(app, hitx, hity)
           %Find the object position at the given position. Measurements 
           %have priority over ROIs.
           %Input: hitx - x-position
           %       hity - y-position
           
            %Find the selection position for multiple views
            if(app.view_axis == 3)
            elseif(app.view_axis == 2)
                tmp = hitx;
                hitx = hity;
                hity = tmp;
            elseif(app.view_axis == 1)
                tmp = hitx;
                hitx = hity;
                hity = tmp;
            end
            selector = round(app.selector_size/100*                 ...
                                max(size(app.data.img(:,:,:,1))));

            %Find the segmentation values at the given position
            if(app.view_axis == 3)
                hitxrange = intersect(1:size(app.data.img,2),           ...
                                        hitx-selector:hitx+selector);
                hityrange = intersect(1:size(app.data.img,1),           ...
                                        hity-selector:hity+selector);
                nn = app.segmentation.img(                              ...
                            hityrange,hitxrange,app.current_slice);
            elseif(app.view_axis == 2)
                hitxrange = intersect(1:size(app.data.img,3),           ...
                                        hitx-selector:hitx+selector);
                hityrange = intersect(1:size(app.data.img,1),           ...
                                        hity-selector:hity+selector);
                nn = app.segmentation.img(                              ...
                            hityrange,app.current_slice,hitxrange);
            elseif(app.view_axis == 1)
                hitxrange = intersect(1:size(app.data.img,3),           ...
                                        hitx-selector:hitx+selector);
                hityrange = intersect(1:size(app.data.img,2),           ...
                                        hity-selector:hity+selector);
                nn = app.segmentation.img(                              ...
                            app.current_slice,hityrange,hitxrange);
            end
            
            %Check if there is a segmentation object at the position
            nn = nn(:);
            for ix=1:length(nn)
                ij = nn(ix);
                if(ij ~= 0)
                    delObj = 1;
                    break;
                end
            end
            
            %Check if there is a measurement at the given position.
            lines   = app.drawing.measurement_lines;
            if(app.view_axis == 3)
                meas_pts = find(lines(:,3) == app.current_slice &   ...
                    lines(:,1) >= hitxrange(1)      &               ...
                    lines(:,1) <= hitxrange(end)    &               ...
                    lines(:,2) >= hityrange(1)      &               ...
                    lines(:,2) <= hityrange(end));
            elseif(app.view_axis == 2)
                meas_pts = find(lines(:,2) == app.current_slice &   ...
                    lines(:,3) >= hitxrange(1)      &               ...
                    lines(:,3) <= hitxrange(end)    &               ...
                    lines(:,1) >= hityrange(1)      &               ...
                    lines(:,1) <= hityrange(end));
            elseif(app.view_axis == 1)
                meas_pts = find(lines(:,1) == app.current_slice &   ...
                    lines(:,2) >= hitxrange(1)      &               ...
                    lines(:,2) <= hitxrange(end)    &               ...
                    lines(:,3) >= hityrange(1)      &               ...
                    lines(:,3) <= hityrange(end));
            end

            if(~isempty(meas_pts))
                % MEASUREMENTS ARE PRIORITY IN DELETION
                disp('Found meas points');
                delObj = 2;
            end
        end
        
        
    end
end
