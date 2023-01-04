classdef Study < handle
    %This static class deals with all functions that specifically change
    %the variables related to the currently loaded study.
    %These include:
    %   app.measurement_list
    methods (Static)
        
        function InitStudy(app)
            %Initialises all objects that are used when working with a
            %study. Called after PrepareStudy.

            %First, remove everything from the screen
            GUI.ResetViews(app);
            
            nImages     = length(app.studyNames);
            if nImages == 0
                return
            end
            
            d = uiprogressdlg(app.UIFigure, 'Title',...
                'New Patient');
            
            %Initiatalize study variables
            app.userObjects         = {};
            app.imagePerAxis        = [];
            app.slicePerImage       = {};
            app.viewPerImage        = ones(1,nImages);
            app.d4PerImage          = ones(1,nImages);
            app.points              = {[],[]};
            app.data                = cell(nImages, 1);
            app.unsavedProgress     = false;
            app.zoomPerImage        = cell(nImages, 1);
            app.viewingParams       = [1,1,1,1, -1,-1,-1];
            
            if isempty(app.user_profile)
                app.user_profile = '';
            end
            
            Backups.ClearBackups(app)
            
            %Find if any files have user objects associated with them
            Study.FindUOsOnDisk(app)

            %Determine rwc reference
            Study.FindRealWorldReference(app)
            
            %Load the first two images (preferably with UOs attached)
            loadCounter = 0;
            for i = 1:length(app.studyNames)
                if loadCounter >= 2
                    break
                end
                item = app.AvailableimagesListBox.Items{i};
                if strcmp(item(1:2), '* ')
                        
                    IOUtils.LoadNii(app, i)
                    IOUtils.LoadUserObjects(app, i);
                    app.imagePerAxis(loadCounter + 1) = i;
                    loadCounter = loadCounter + 1;
                end
            end
            
            %fill the other images
            for i = 1:length(app.studyNames)
                if loadCounter >= 2
                    break
                end
                
                if any(app.imagePerAxis == i)
                    continue
                end
                msg = sprintf('Loading image %d of 2', loadCounter + 1);
                d.Message = msg;
                d.Value = (loadCounter + 1)/ 2;
                
                IOUtils.LoadNii(app, i)
                IOUtils.LoadUserObjects(app, i);
                app.imagePerAxis(loadCounter + 1) = i;
                loadCounter = loadCounter + 1;
            end                
            
            %Initialize the window
            GUI.InitGUI(app)
            Backups.ClearBackups(app)
            Backups.CreateBackup(app)
            Study.ToggleUnsavedProgress(app, false)
            close(d);
            
        end
        
        function FindUOsOnDisk(app)
            
            nImages     = length(app.studyNames);
            for idx = 1:nImages
                folder      = app.studyNames{idx};
                direc       = fullfile(app.current_folder,...
                        folder);
                files       = dir(fullfile(direc, '*.json')); 
                if isempty(files)
                    continue
                end
                
                %More files found -> UOs probably exist
                %TODO, don't store this in availabnleImagesListbox...
                GUI.ToggleUOPresence(app, idx)                
            end
            
        end               
        
        function SaveToDisk(app)
            %Saves the current study to the .rmsstudio folder. All the 
            %User-made objects are written to either .nii or .csv files.
            
            for imageId=1:length(app.studyNames)
                fn      = app.studyNames{imageId};
                
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

            if index > length(app.slicePerImage)
                app.slicePerImage{index} = {[],[],[]};
                IOUtils.LoadNii(app, index)
                IOUtils.LoadUserObjects(app, index)
                app.imagePerAxis(app.current_view) = index;
                GUI.DisplayNewImage(app, index)
                return
            end
            
            if isempty(app.slicePerImage{index}) %Image not loaded before
                IOUtils.LoadNii(app, index)
                IOUtils.LoadUserObjects(app, index)
                app.imagePerAxis(app.current_view) = index;
                GUI.DisplayNewImage(app, index)
                return
            end
            
            %Load the image, segmentations and measurement into the study,
            %either from disk, or from the list.
            if isempty(app.data{index})
                GUI.DisableControlsStatus(app)
                IOUtils.LoadNii(app, index)    
                IOUtils.LoadUserObjects(app, index)
                GUI.RevertControlsStatus(app)
            end
            app.imagePerAxis(app.current_view) = index;
            GUI.SwitchImage(app, index)
        end
               
        
        function ToggleUnsavedProgress(app, status)
            app.unsavedProgress = status;
            GUI.ToggleUnsavedIndicator(app)
        end

        function FindRealWorldReference(app)
        %Finds the transformation matrix and image orientation for each
        %scan. This info is then used to find a mean neutral viewing
        %reference point.
        
            fp = app.current_folder;
            refs = ones(3,length(app.studyNames));
        
            for i = 1:length(app.studyNames)
                fn = app.studyNames{i};

                if(exist(fullfile(fp,[fn '.nii']),'file') > 0)
                    ext = '.nii';
                elseif(exist(fullfile(fp,[fn '.nii.gz']),'file') > 0)
                    ext = '.nii.gz';
                else
                    error('Cannot find the specified file.');
                end
                hdr =  load_untouch_header_only(fullfile(fp,[fn ext]));
                tm  = NiftiUtils.getTransformationMatrix(hdr);
                app.transMatPerImage{i} = tm;
                or  = NiftiUtils.FindOrientation(tm);
                app.viewPerImage(i) = ...
                    strfind('sca',or(5)); %1 = sag, 2=cor, 3=axial

                refs(:,i) =...
                    NiftiUtils.GetRefHalfway(hdr);

            end

            meanRef = mean(refs, 2);
            app.viewingParams(1:3) = meanRef;

        end
        
        
    end
end
