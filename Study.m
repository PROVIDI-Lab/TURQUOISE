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
            if nImages == 0
                return
            end
            
            %Initiatalize study variables
            app.userObjects         = {};
            app.slicePerImage       = ones(1,nImages)*-1;
            app.viewPerImage        = ones(1,nImages)*3;
            app.d4PerImage          = ones(1,nImages);
            app.points              = {[],[]};
            app.data                = cell(nImages,1);
            
            if isempty(app.user_profile)
                app.user_profile = {''};
            end
            
            %Load the first (2) image(s)
            IOUtils.LoadNii(app, 2);     
            IOUtils.LoadNii(app, 1);     
            
            %Load all user objects from disk
            for idx = 1:nImages
                Study.LoadFromDisk(app, idx)
            end
            
            %Initialize the window
            GUI.InitGUI(app)
            
        end
        
        
        function LoadFromDisk(app, index)
        %Load the segmentation and any measurements from disk when
        %it hasn't already been loaded.
        %Input: index - index of the image in AvailableImageListBox
            
        
            IOUtils.LoadUserObjects(app, index);
        end
               
        
        function SaveToDisk(app)
            %Saves the current study to the .rmsstudio folder. All the 
            %User-made objects are written to either .nii or .csv files.
            
            
            %First save the most recent changes to the list
%             Study.SaveToList(app, app.current_view)
            
            
            for imageId=1:length(app.AvailableimagesListBox.Items)
                fn      = app.AvailableimagesListBox.Items{imageId};
                outfn   = fullfile(app.current_folder,              ...
                                        fn(1:end-4),                    ...
                                         app.user_profile{1});
                                     
                IOUtils.saveUObjs(app, imageId, outfn);
            end
        end
        
        function SwitchImage(app, index)
        % Switches workspace and display to a different image.
        % Input:
        %   app, reference to the RMSStudio app
        %   index, index of image in the available_image_box
            
            if app.imIdx == index
                return
            end
            %Switch to new image
            app.imIdx = index;
            
            if app.slicePerImage(index) == -1 %Image not loaded before
                IOUtils.LoadNii(app, index)
                app.imagePerAxis(app.current_view) = index;
                GUI.DisplayNewImage(app, index)
                return
            end
            
            
            %Load the image, segmentations and measurement into the study,
            %either from disk, or from the list.
            if isempty(app.data{index})
                IOUtils.LoadNii(app, index)     
            end
            app.imagePerAxis(app.current_view) = index;
            GUI.SwitchImage(app, index)
        end
               
        
        function [delObj, ij, meas] = FindObjectTypeAtPos(app, hitx, hity)
        %Find the object position at the given position. Measurements 
        %have priority over ROIs.
        %Input: hitx - x-position
        %       hity - y-position
        %TODO: Split & Move function
        %TODO: update for userobjects
           
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            %Find the selection position for multiple views
            if(view == 3)
            elseif(view == 2)
                tmp = hitx;
                hitx = hity;
                hity = tmp;
            elseif(view == 1)
                tmp = hitx;
                hitx = hity;
                hity = tmp;
            end
            
            
            selector    = round(app.selector_size/100*...
                            max(size(app.data{app.imIdx}.img(:,:,:,1))));
            nn          = [];
            
            delObj      = 0;
            ij          = [];
            meas        = [];
            
                        
            %Find the segmentation values & measurement lines 
            %at the given position
            if(view == 3)
                hitxrange = intersect(...
                        1:size(app.data{app.imIdx}.img,2),...
                        hitx-selector:hitx+selector);
                hityrange = intersect(...
                    1:size(app.data{app.imIdx}.img,1),...
                    hity-selector:hity+selector);
                if isfield(app.segmentation{Cv},'img')
                    nn = app.segmentation{Cv}.img(...
                                hityrange,hitxrange,slice);
                end
                if ~isempty(app.measure_lines{Cv})
                    lines   = app.measure_lines{Cv}(:,[1,2]);
                    distances       = zeros(1,round(length(lines)/2));
                    for i = 1:2:length(lines)
                        distances(round((i+1)/2)) =...
                            Study.CalcDistancePointLine([hitx, hity],...
                                                lines(i,:), lines(i+1,:));
                    end
                    [d, idx]    = min(distances);
                    if d <= selector
                        meas    = idx;
                    end
                    
%                     meas = find(lines(:,3) == app.current_slice &       ...
%                         lines(:,1) >= hitxrange(1)      &               ...
%                         lines(:,1) <= hitxrange(end)    &               ...
%                         lines(:,2) >= hityrange(1)      &               ...
%                         lines(:,2) <= hityrange(end));
                end
                
            elseif(view == 2)
                hitxrange = intersect(...
                    1:size(app.data{app.imIdx}.img,3),...
                    hitx-selector:hitx+selector);
                hityrange = intersect(...
                    1:size(app.data{app.imIdx}.img,1),...
                    hity-selector:hity+selector);
                if isfield(app.segmentation{Cv},'img')
                    nn = app.segmentation{Cv}.img(...
                            hityrange,slice,hitxrange);
                end
                if ~isempty(app.measure_lines{Cv})
                    lines   = app.measure_lines{Cv}(:,[1,3]);
                    distances       = zeros(round(length(lines)/2));
                    for i = 1:2:length(lines)
                        distances(round((i+1)/2)) =...
                            CalcDistancePointLine([hitx, hity],...
                                            lines(i), lines(i+1));
                    end
                    [d, idx]    = min(distances);
                    if d <= selector
                        meas    = idx;
                    end
                end
                
            elseif(view == 1)
                hitxrange = intersect(...
                    1:size(app.data{app.imIdx}.img,3),...
                    hitx-selector:hitx+selector);
                hityrange = intersect(...
                    1:size(app.data{app.imIdx}.img,2),...
                    hity-selector:hity+selector);
                
                if isfield(app.segmentation{Cv},'img')
                    nn = app.segmentation{Cv}.img(...
                        slice,hityrange,hitxrange);
                end
                if ~isempty(app.measure_lines{Cv})
                    lines   = app.measure_lines{Cv}(:,[2,3]);
                    distances       = zeros(round(length(lines)/2));
                    for i = 1:2:length(lines)
                        distances(round((i+1)/2)) =...
                            CalcDistancePointLine([hitx, hity],...
                                            lines(i), lines(i+1));
                    end
                    [d, idx]    = min(distances);
                    if d <= selector
                        meas    = idx;
                    end
                end
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

            if(~isempty(meas))
                % MEASUREMENTS ARE PRIORITY IN DELETION
                delObj = 2;
            end
        end
        
        function dist = CalcDistancePointLine(p0, p1, p2)
        %Calculates the closest distance between a point and a line 
        %(as defined by two points).
        %See: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
            
            x0  = p0(1); y0  = p0(2); x1  = p1(1); y1  = p1(2);
            x2  = p2(1); y2  = p2(2);
            
            dist    = abs( (x2-x1)*(y1-y0) - (x1-x0)*(y2-y1)) / ...
                sqrt((x2-x1)^2 + (y2-y1)^2);
            
        end
        
        
    end
end
