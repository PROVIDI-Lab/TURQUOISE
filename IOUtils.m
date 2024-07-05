classdef IOUtils < handle

    methods (Static)        
        %% Loading & Saving files
        
        function LoadNii(app, index)
        %Loads the .nii file associated with the current
        %image. Sets the nii file as the current image.
        %Input: 
        %   app, the app
        %   Index, the index of the image currently being loaded
        
            fp = app.sessionPath;
            try
                fn = app.sessionNames{index};
            catch
                return
            end
            if strcmp(fn(1:2), '* ')
                    fn = fn(3:end);
            end

            if ~contains(fn, '.nii')
                name = fullfile(fp,[fn '.nii']);
                if exist(name, 'file') == 0 
                    name = [name '.gz'];
                    %return
                end
            else
                name    = fullfile(fp,fn);
            end

            %Load the file
            nii         = load_untouch_nii(name);
            nii.img     = single(nii.img);

            %correct orientation for display in matlab
            nii         = NiftiUtils.PermuteFlip(nii);

            %interpolate image based on reference
%             rwcImg      = NiftiUtils.MoveToRWC(app, nii);
%             nii.img     = rwcImg;

%             %for testing
%             imshowpair(nii.img(:,:,round(size(nii.img, 3)/2)), ...
%                 rwcImg(:,:,round(size(nii.img, 3)/2)))
            
            app.data{index}         = nii;
            app.d4PerImage(index)   = 1;
            app.DSlider.Value       = 1;
        
        end
        
        function saveUObjs(app, imageId, fn)
        %Saves all the user objects for the current image
        
            %First find all uos for that image
            UOIDs = Objects.GetAllUOIdxForImage(app, imageId, false, ...
                false);

            if ~isfolder(fn) && ~isempty(UOIDs)
                mkdir(fn);
            end
            
            for i = UOIDs
                uObj    = app.userObjects{i};

                profileFn = fullfile(fn, uObj.profile);

                if ~exist(profileFn, 'dir')
                    mkdir(profileFn)
                end

                if uObj.deleted
                    %Remove all previous saved data if any
                    delete(fullfile(profileFn, [uObj.name,'*']))  
                    continue
                end

                IOUtils.saveSegmentationPoints(uObj, profileFn);
                IOUtils.saveSegmentation(app, uObj, profileFn)
            end
        end
        
        function saveSegmentation(app, obj, fn)
        %Saves the array with the segmentation labels to a .nii file
        %Input:
        %   obj 	- the userObject with the segmentation to be saved
        %   fn      - name of the .nii output file
            
            outFn   = fullfile(fn,...
                        [obj.name, '-segmentation.nii.gz']);

            if exist(outFn, 'file')
                delete(outFn)
            end

            nii     = IOUtils.arr2nii(app, obj);
            try
                save_untouch_nii(nii, outFn);
            catch err
                uialert(uifigure,err.message,...
                    'Unable to save segmentation');
            end             
        end
        
        function saveSegmentationPoints(obj, fn)
            %Saves the roiPoints to a json object.
            
            outFn   = fullfile(fn,...
                        [obj.name, '-segmentation.json']);

            if exist(outFn, 'file')
                delete(outFn)
            end
            
            %write new json to disk
            jsonObj     = struct(   'points', obj.points, ...
                                    'type', obj.type, ...
                                    'viewDim', obj.viewDim,...
                                    'comment', obj.comment, ...
                                    'volume', obj.volume, ...
                                    'mean', obj.meanVal, ...
                                    'std', obj.stdVal, ...
                                    'prctile5', obj.prctile5, ...
                                    'prctile25', obj.prctile25, ...
                                    'prctile50', obj.prctile50, ...
                                    'prctile75', obj.prctile75, ...
                                    'prctile95', obj.prctile95);
            txt         = jsonencode(jsonObj);
            
            fid         = fopen(outFn, 'w');
            fwrite(fid, txt, 'char');
            fclose(fid);
        end
        
        function LoadUserObjects(app, idx)
            %Loads userobjects from the disk that correspond to the image
            %at idx.
            folder      = app.sessionNames{idx};

            direc       = fullfile(app.sessionPath, folder);
            %First find any segmentations
            segFiles    = [dir(fullfile(direc,'**\*.nii')), ...
                dir(fullfile(direc, '**\*.nii.gz'))];
            for file = segFiles'
                
                basename = erase(file.name, {'.nii', '.gz'});
                if exist(fullfile(file.folder, [basename, '.json']), 'file')
                    IOUtils.loadSegmentationPoints(...
                        app, fullfile(file.folder, [basename, '.json']), idx);
                else
                    IOUtils.LoadSegmentation(app, ...
                        fullfile(file.folder, file.name), idx)
                end
            end
                    
            %Next, load measurements
            IOUtils.LoadMeasurements(...
                app, fullfile(direc,'measurements.csv'), idx);
        end
        
        
        function LoadSegmentation(app, fn, idx)
        %Loads a segmentation from a .nii file and creates a userObject.
            
            if(exist(fn,'file') == 0)
                return
            end
            nii     = load_untouch_nii(fn);
            nii     = NiftiUtils.PermuteFlip(nii);
            nii.img = nii.img(:,:,:,1); 

            [~, name, ~]    = fileparts(fn);
            name            = erase(name, {'.nii', '.gz', '-segmentation'});

            %Get polygon points from the label
            %Assume that the viewdim is the same as the image orientation
            %TODO: prompt user?
            viewDim = 3;
            points = ROI.MaskToPoints(nii.img, [-1,-1,-1], viewDim);

            if isempty(points)
                uialert(app.UIFigure, 'This segmentation seems empty.',...
                    'Segmentation error');
                return
            end

            %find profile, if any
            [base, ~, ~] = fileparts(fn);
            [base, folder, ~] = fileparts(base);
            [~, superfolder, ~] = fileparts(base);
            if strcmp(superfolder, 'rmsstudio')
                profile = ''; %no profile
            else
                profile = folder;
            end
            
            Objects.AddNewUserObj(app,...
                    "type", 1, ...
                    "points", points, ... 
                    "data", single(nii.img),...
                    "name", name,...
                    "imageIdx", idx, ...
                    "profile", profile) 
        end
        
        function loadSegmentationPoints(app, fn, idx)
            
            %Loads the points stored in the -segmentation.json file 
            %associated with the current image.
            if(exist(fn,'file') == 0)
                return
            end
            
            fid  = fopen(fn, 'r');
            txt  = fread(fid,inf);
            txt  = char(txt');
            fclose(fid);
            data = jsondecode(txt);
            
            %Find obj name
            %TODO: more elegantly
            beginPos    = strfind(fn,filesep);
            beginPos    = beginPos(end);
            endPos      = strfind(fn,'-');
            endPos      = endPos(end);
            name        = fn(beginPos + 1: endPos - 1);

            %find obj profile
            [folder, ~, ~] = fileparts(fn);
            [~, profile, ~] = fileparts(folder);
            if contains(app.AvailableimagesListBox.Items{idx}, profile)
                profile = '';
            end
            
            %Load points
            points = data.points;            
            points(any(isnan(points),2),:) = [];
            
            if isfield(data, 'type')
                type = data.type;
            else
                type = 1;
            end

            if isfield(data, 'viewDim')
                viewDim = data.viewDim;
            else
                viewDim = 3;
            end

            if isfield(data, 'comment')
                comment = data.comment;
            else
                comment = '';
            end

            mask = ROI.PointsToMask(app, points, idx, type, viewDim);
            Objects.AddNewUserObj(app,...
                    "type", type, ...
                    "data", mask,...
                    "points", data.points,...
                    "name", name,...
                    "imageIdx", idx,...
                    'comment', comment, ...
                    'profile', profile);

            %Add new UO to the selectionbox
            GUI.UpdateUOBox(app);

            %Create a new layer in the imagerenderer (if the UO is
            %currently being shown)
            obj = app.userObjects{end};
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
        end
        
        function LoadMeasurements(app, name, idx)
        %Load all the measurements from the disk     
        %Todo: incorporate all measurements & ROIS in single json
            if(exist(name,'file') == 0)
                return
            end

            %Read measurement from .xlsx file
            table = readtable(name);

            for line_id = 1:size(table,1)
                P11     = table.P1_1(line_id);
                P12     = table.P1_2(line_id);
                P13     = table.P1_3(line_id);
                P21     = table.P2_1(line_id);
                P22     = table.P2_2(line_id);
                P23     = table.P2_3(line_id);
                
                Objects.AddNewUserObj(app,...
                    "type", 2, ...
                    "points", [P11, P12, P13, P21, P22, P23], ...
                    "name", table.Measurement(line_id),...
                    "imageIdx", idx);
                
            end
        end
        
        %%
        
        function PrepareStudy(app, filepath)
        %Prepares a new study when the 'Load' button is pressed.
        %First checks if the Study has already been processed (contains a
        %rmsstudio folder). If so, loads all items from that folder. If no
        %previously processed folder exists, or if the rmsstudio folder is
        %empty, it converts any dicom images to nii standard.
                    
            if ~exist('filepath','var')
                
                if ~isempty(app.filepath)
                    targetDir = fullfile(app.filepath, '..');
                    fp = uigetdir(targetDir,'Select a subject folder');
                else
                    fp = uigetdir('C:','Select a subject folder');
                end
                if(isnumeric(fp) && fp == 0)
                    app.UIFigure.Visible = 'on';
                    return
                end
            else
                fp              = filepath;
            end
            app.sessionPath = filepath;
            
            %Convert files to nii (if needed), find original filenames and
            %set the 'sessionPath' object.
            
            IOUtils.findRmsstudioDir(app, fp) %Find the path to rmsstudio
            try
                IOUtils.convertToNii(app);
                app.UIFigure.Name   = ['RMSStudio ' app.sessionPath];
            catch err
%                 close(h);
                uialert(uifigure,err.message,'');
            end
            
            try
%                 close(h)
                app.UIFigure.Visible = 'on';
            catch 
            end
            
            %Go over all files and check viability etc.
            IOUtils.CheckNiis(app)
            %Initialises the study objects
            Study.InitStudy(app)
            
        end
        
        function CheckNiis(app)
        %Goes over all nii files in the current folder and add them to
        %app.sessionNames
        % TODO: add header checking!!
                        
            files = dir(fullfile(app.sessionPath,...
                '*.nii'));

            cfiles = dir(fullfile(app.sessionPath,...
                '*.nii.gz'));

            files = [files; cfiles];
            
            app.sessionNames = cell(length(files),1);
            
            files2keep = true(length(files),1);

            for file_id=1:length(files)
                text        = files(file_id).name; 
                hdr = load_untouch_header_only(fullfile(app.sessionPath,text));
                if(hdr.dime.dim(4) == 1) % Only 1 slice
                    files2keep(file_id) = false;
                end

                text = erase(text, '.nii.gz');
                app.sessionNames{file_id} = erase(text, '.nii');
            end
            
            app.AvailableimagesListBox.Items = app.sessionNames(files2keep);
            app.sessionNames = app.sessionNames(files2keep);
        end
        
        function convertToNii(app)
            %If no previous conversions exist, Create a rmsstudio 
            %directory with .nii versions of all the files using dcm2nii.
                
            if(numel(dir(app.sessionPath)) == 2)
                %If folder exists, but is emtpy, try to load dicom images.
                %only elements in folder are '.' & '..'
                dcm2nii = IOUtils.checkDcm2Nii();
                if isempty(dcm2nii)
                    return
                end
                cmd = [dcm2nii ' -f %d_%s -z y -o "'                     ...
                        app.sessionPath '" "'  app.filepath '"'];
                system(cmd);
            end
        end
        
        function dcm2nii = checkDcm2Nii()
            %Find the path of dcm2nii
            %Returns: path to dcm2nii
            if exist('dcm2nii','dir')
                dcm2nii = what('dcm2nii');

                %if multiple versions exist, take the first one
                if ~all(size(dcm2nii) == 1)
                    dcm2nii = dcm2nii(1);
                end

                dcm2nii = strcat(dcm2nii.path, '\dcm2niix');                
                
            else
                dcm2niiDir  = uigetdir('C:', 'Please locate dcm2nii');
                if dcm2niiDir == 0
                    dcm2nii = '';
                    return
                end
                addpath(dcm2niiDir)
                dcm2nii     = fullfile(dcm2niiDir, 'dcm2niix');
            end
            
        end
        
        function nii = arr2nii(app, obj)
        %Constructs a nii object from the user object containing an ROI
            
            nii         = app.data{obj.imageIdx};
            nii.img     = obj.data;
            
            %Undo the permutation done when reading the nii
            nii = NiftiUtils.FlipPermute(nii);
        
        end
        
        function findRmsstudioDir(app, fp)
            %Searches the current workspace for a dir that includes 
            %'rmsstudio' in its name. Sets this as app.sessionPath.
            %If no such folder exists, one is made.
            app.sessionPath = [];
            
            %If the path already contains the rmsstudio folder, return
            if contains(fp, 'rmsstudio')
                app.sessionPath = fp;
                return
            end
            
            items = dir(fp);
            for i = 3:length(items)
               item = items(i);
               if ~item.isdir
                   continue
               elseif ~contains(item.name, 'rmsstudio')
                   continue
               end
               
               app.sessionPath = fullfile(item.folder, item.name); 
               break
            end
            
            %Doesn't exist, make the folder
            if isempty(app.sessionPath)
                mkdir(fullfile(fp,'rmsstudio'))
                app.sessionPath = fullfile(fp,'rmsstudio');
            end
            
        end

        function segList = FindAllSegmentationsForImage(app, i)
            
            segList = {};
            files = dir(fullfile(app.sessionPath,              ...
                        app.sessionNames{i},   ...
                         app.user_profile));

            for i = 1:length(files)
                file = files(i);
                if file.isdir
                    continue
                end

                [~, name, ext] = fileparts(...
                    fullfile(file.folder, file.name));
                name = strrep(name,'-segmentation', '');

                if ~strcmp(ext, '.json')
                    continue
                end

                segList{end+1} = name;
            end
        end

        function InitPreferences()

            try
                ispref('rmsstudio', 'datasets')
            catch
                delete(fullfile(prefdir, 'matlabprefs.mat'))
                
                addpref('rmsstudio', 'datasets', [])
                addpref('rmsstudio', 'profiles', [])
                addpref('rmsstudio', 'ROILst', [])
            end
            
            if ~ispref('rmsstudio', 'ROILst')
                    addpref('rmsstudio', 'ROILst', [])
            end
            if ~ispref('rmsstudio', 'datasets')
                    addpref('rmsstudio', 'datasets', [])
            end
            if ~ispref('rmsstudio', 'profiles')
                    addpref('rmsstudio', 'profiles', [])
            end
        end
        
    end
   
end