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
            
            GUI.newPatientWaitBar(app)
            
            %Initiatalize study variables
            app.userObjects         = {};
            app.slicePerImage       = ones(1,nImages)*-1;
            app.viewPerImage        = ones(1,nImages)*3;
            app.d4PerImage          = ones(1,nImages);
            app.points              = {[],[]};
            app.data                = cell(nImages,1);
            
            if isempty(app.user_profile)
                app.user_profile = '';
            end
            
            %Find if any files have user objects associated with them
            Study.FindUOsOnDisk(app)
            
            loadCounter = 0;
            for i = 1:length(app.AvailableimagesListBox.Items)
                if loadCounter >= 2
                    break
                end
                item = app.AvailableimagesListBox.Items{i};
                if strcmp(item(1:2), '* ')
                    msg = sprintf('Loading image %d of 2', loadCounter + 1);
                    GUI.updateWaitBar(app, msg, (loadCounter + 1)/ 2)
                        
                    IOUtils.LoadNii(app, i)
                    IOUtils.LoadUserObjects(app, i);
                    app.imagePerAxis(loadCounter + 1) = i;
                    loadCounter = loadCounter + 1;
                end
            end
            
            %fill the other images
            for i = 1:length(app.AvailableimagesListBox.Items)
                if loadCounter >= 2
                    break
                end
                
                if any(app.imagePerAxis == i)
                    continue
                end
                msg = sprintf('Loading image %d of 2', loadCounter + 1);
                GUI.updateWaitBar(app, msg, (loadCounter + 1)/ 2)
                IOUtils.LoadNii(app, i)
                IOUtils.LoadUserObjects(app, i);
                app.imagePerAxis(loadCounter + 1) = i;
                loadCounter = loadCounter + 1;
            end                
            
            %Initialize the window
            GUI.InitGUI(app)
            GUI.closeWaitBar(app)
            
        end
        
        function FindUOsOnDisk(app)
            
            nImages     = length(app.AvailableimagesListBox.Items);
            for idx = 1:nImages
                folder      = app.AvailableimagesListBox.Items{idx};
                direc       = fullfile(app.current_folder,...
                        folder);
                files       = dir(fullfile(direc, '*.json')); 
                if isempty(files)
                    continue
                end
                
                %More files found -> UOs probably exist
                GUI.ToggleUOPresence(app, idx)                
            end
            
        end
        
        
%         function LoadFromDisk(app, index)
%         %Load the segmentation and any measurements from disk when
%         %it hasn't already been loaded.
%         %Input: index - index of the image in AvailableImageListBox
%             
%             IOUtils.LoadUserObjects(app, index);
%         end
               
        
        function SaveToDisk(app)
            %Saves the current study to the .rmsstudio folder. All the 
            %User-made objects are written to either .nii or .csv files.
            
            for imageId=1:length(app.AvailableimagesListBox.Items)
                fn      = app.AvailableimagesListBox.Items{imageId};
                
                if strcmp(fn(1:2), '* ')
                    fn = fn(3:end);
                end
                
                outfn   = fullfile(app.current_folder,              ...
                                        fn,                         ...
                                         app.user_profile);
                                     
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
                IOUtils.LoadUserObjects(app, index)
                app.imagePerAxis(app.current_view) = index;
                GUI.DisplayNewImage(app, index)
                return
            end
            
            
            %Load the image, segmentations and measurement into the study,
            %either from disk, or from the list.
            if isempty(app.data{index})
                IOUtils.LoadNii(app, index)    
                IOUtils.LoadUserObjects(app, index)
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
                            MathUtils.CalcDistancePointLine([hitx, hity],...
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
                            MathUtils.CalcDistancePointLine([hitx, hity],...
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
                            MathUtils.CalcDistancePointLine([hitx, hity],...
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
        
        
    end
end
