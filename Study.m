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
            
            nImages     = length(app.sessionNames);
            if nImages == 0
                return
            end
            
            d = uiprogressdlg(app.UIFigure, 'Title',...
                'New Patient');
            
            %Initiatalize study variables
            app.userObjects         = {};
            app.hasUO               = false(nImages, 1);
            app.imagePerAxis        = [1, 2];
            app.slicePerImage       = cell(nImages, 1);
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
            imList = [];
            for i = find(app.hasUO)'
                if length(imList) >= 2
                    break
                end

                IOUtils.LoadNii(app, i)
                app.imagePerAxis(length(imList) + 1) = i;
                imList(end+1) = i;
            end
            
            %fill the other images
            for i = 1:length(app.sessionNames)
                if length(imList) >= 2
                    break
                end
                
                if any(app.imagePerAxis == i)
                    continue
                end
                msg = sprintf('Loading image %d of 2', ...
                    length(imList) + 1);
                d.Message = msg;
                d.Value = (length(imList) + 1)/ 2;
                
                IOUtils.LoadNii(app, i)
                app.imagePerAxis(length(imList) + 1) = i;
                imList(end+1) = i;
            end                
            
            %Initialize the window
            GUI.InitGUI(app)
            Backups.ClearBackups(app)
            Backups.CreateBackup(app)
            Study.ToggleUnsavedProgress(app, false)
            close(d);

            %when GUI isn't initialised, we can't load UOs yet. Does do
            %some stuff double, but it's not a big problem I think..
            IOUtils.LoadUserObjects(app, imList(1))
            IOUtils.LoadUserObjects(app, imList(2))

            GUI.InitUORenderer(app, 1)
            GUI.InitUORenderer(app, 2)
            
        end
        
        function FindUOsOnDisk(app)
            
            nImages     = length(app.sessionNames);
            for idx = 1:nImages
                folder      = app.sessionNames{idx};
                direc       = fullfile(app.sessionPath,...
                        folder);
                jsonfiles       = dir(fullfile(direc, '**\*.json')); 
                niifiles        = dir(fullfile(direc, '**\*.nii')); 
                niigzfiles      = dir(fullfile(direc, '**\*.nii.gz')); 
                
                if isempty(jsonfiles) && isempty(niifiles) && isempty(niigzfiles)
                    continue
                end
                
                GUI.ToggleUOPresence(app, idx)                
            end
            
        end               
        
        function SaveToDisk(app)
            %Saves the current study to the .rmsstudio folder. All the 
            %User-made objects are written to either .nii or .csv files.
            
            for imageId=1:length(app.sessionNames)
                fn      = app.sessionNames{imageId};                
                outfn   = fullfile(app.sessionPath,              ...
                                        fn);
                                     
                IOUtils.saveUObjs(app, imageId, outfn);
            end
        end
        
        function SwitchImage(app, index)
        % Switches workspace and display to a different image.
        % Input:
        %   app, reference to the app
        %   index, index of image in the available_image_box
            
            if app.imID == index
                return
            end
            
            %Switch to new image
            app.imID = index;

            %Image not loaded before
            if isempty(app.data{index})
                GUI.DisableControlsStatus(app)
                app.imagePerAxis(app.axID) = index;
                IOUtils.LoadNii(app, index)

                GUI.DisplayNewImage(app, index)
                IOUtils.LoadUserObjects(app, index)
                Backups.CreateBackup(app)
                GUI.RevertControlsStatus(app)
                return
            end
            
            %Image loaded before
%             GUI.DisableControlsStatus(app)
            app.imagePerAxis(app.axID) = index;
            GUI.SwitchImage(app, index)
%             GUI.RevertControlsStatus(app)
        end
               
        
        function ToggleUnsavedProgress(app, status)
            app.unsavedProgress = status;
            GUI.ToggleUnsavedIndicator(app)
        end

        function FindRealWorldReference(app)
        %Finds the transformation matrix and image orientation for each
        %scan. This info is then used to find a mean neutral viewing
        %reference point.
        
            fp = app.sessionPath;
            refs = ones(3,length(app.sessionNames));
        
            for i = 1:length(app.sessionNames)
                fn = app.sessionNames{i};

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
                    strfind('csa',or(5)); %1 = cor, 2=sag, 3=axial

                refs(:,i) =...
                    NiftiUtils.GetRefHalfway(hdr);

            end

            meanRef = mean(refs, 2);
            app.viewingParams(1:3) = meanRef;

        end
        
        
    end
end
