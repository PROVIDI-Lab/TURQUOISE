classdef IOUtils < handle

    methods (Static)
        
        % After nifti import
%         function [nii, ratio] = RMSStandardVolumeTreatment(app, nii)
%             if app.interpolateImages
%                 min_vs = min(nii.hdr.dime.pixdim(2:1+ndims(nii.img)));
%                 tic
%                 [nii.img, ratio] = MathUtils.ResampleVolume(nii.img,  ...
%                                    nii.hdr.dime.pixdim(2:4), ...
%                                    min_vs*ones(1,3));
%                 toc
%             else
%                 ratio = [1,1,1];
%             end
%             nii.img = permute(nii.img,[2 1 3 4]);
%             nii.img = flip(nii.img,1);
%             nii.img = flip(nii.img,2);
%             nii.img = flip(nii.img,3);
%         end
        
        function [nii, ratio] = ResampleNii(nii, inverse)
            min_vs = min(nii.hdr.dime.pixdim(2:1+ndims(nii.img)));
            
            if inverse
                [nii.img, ratio] = MathUtils.ResampleVolume(nii.img,  ...
                   min_vs*ones(1,3),...
                   nii.hdr.dime.pixdim(2:4));
            else
                [nii.img, ratio] = MathUtils.ResampleVolume(nii.img,  ...
                   nii.hdr.dime.pixdim(2:4), ...
                   min_vs*ones(1,3));
            end
        end

        %Permutes and flips the image to match Matlab's orientation of 
        %images. Doesn't change the header, since it's only for in-app use.
        function nii = PermuteFlip(nii)
            nii.img = permute(nii.img,[2 1 3 4]);
            nii.img = flip(nii.img,1);
            nii.img = flip(nii.img,2);
            nii.img = flip(nii.img,3);
        end
        
        % Before save
%         function [nii, ratio] = RMSStandardVolumeDetreatment(nii)        
%             nii.img = single(nii.img);
% %             nii.hdr.dime.dim(1) = 3;
% %             nii.hdr.dime.dim(5) = 1;
%             nii.img = permute(nii.img,[2 1 3]);
%             nii.img = flip(nii.img,1);
%             nii.img = flip(nii.img,2);
%             nii.img = flip(nii.img,3);
%             ratio = [1,1,1];
% %             min_vs = min(nii.hdr.dime.pixdim(2:1+ndims(nii.img)));
%         end 
        
        function ResliceResampleNii(current_file, reslice_file)
        %Loads the rmsstudio_reslice.nii file associated with the current
        %image. Sets the nii file as the current image.
        %Input: 
        %app, the RMSStudio app
        %reslice_name, the path of the file to be resliced
        
            %If the file doesn't exist, reslice it now.
            if(exist(reslice_file,'file') < 1)
                hdr = load_untouch_header_only(current_file);
                try
                    reslice_nii(current_file,                       ...
                                reslice_file,                       ...
                                hdr.dime.pixdim(2:4));
                catch
                    return
                end
                if exist(reslice_file, 'file')
                    nii     = load_nii(reslice_file);
                else
%                     nii     = load_nii(fullfile(fp,fn));
                    return
                end
                
                %Resample file
                [nii, ratio] = IOUtils.ResampleNii(nii, false);
                
                %change header
                nii.hdr.dime.dim(2:1+ndims(nii.img)) = size(nii.img);
                nii.hdr.dime.pixdim(2:4) = nii.hdr.dime.pixdim(2:4)     ...
                                            ./ ratio;
                
                %Save back to disk
                save_nii(nii, reslice_file);
            end
        end   
        
        %% Loading & Saving files
        
        function LoadNii(app, index)
        %Loads the rmsstudio_reslice.nii file associated with the current
        %image. Sets the nii file as the current image.
        %Input: 
        %   app, the RMSStudio app
        %   Index, the index of the image currently being loaded
        
            fp = app.current_folder;
            try
                fn = app.AvailableimagesListBox.Items{index};
            catch
                return
            end
            if strcmp(fn(1:2), '* ')
                    fn = fn(3:end);
            end
            if ~contains(fn, '.rmsstudio_reslice.nii')
                reslice_name = fullfile(fp,[fn '.rmsstudio_reslice.nii']);
                if exist(reslice_name, 'file') == 0
                    return
                end
            else
                reslice_name    = fullfile(fp,fn);
            end
            %Load the file
%             reslice_name    = convertCharsToStrings(reslice_name);
            nii     = load_nii(reslice_name);
            nii     = IOUtils.PermuteFlip(nii);
            nii.img = single(nii.img);
            
            app.data{index}         = nii;
            app.d4PerImage(index)   = 1;
            app.DSlider.Value       = 1;
        
        end
        
        function saveUObjs(app, imageId, fn)
        %Saves all the user objects for the current image
        
%             fn      = fullfile(app.current_folder, ...
%                 app.AvailableimagesListBox.Items{imageId},...
%                 app.user_profile{1});
            if ~isfolder(fn)
                mkdir(fn);
            else
                
                delete(fullfile(fn, '*'))   %Remove all previous saved data
            end
            
            segProperties   = {};
            msrProperties   = {};
            
            for uObj    = app.userObjects
                uObj    = uObj{1};
                if uObj.imageIdx ~= imageId
                    continue
                end
                
                if uObj.type == 1
                    IOUtils.saveSegmentation(app, uObj, fn);
                    IOUtils.saveSegmentationPoints(uObj, fn);
                    segProperties{end+1} = uObj.prop;
                elseif uObj.type == 2
                    msrProperties{end+1} = uObj.prop;
                end
            end
            if ~isempty(segProperties)
                IOUtils.saveObjProperties(segProperties, ...
                    fullfile(fn,'segmentation.csv'));
            end
            if ~isempty(msrProperties)
                IOUtils.saveObjProperties(msrProperties, ...
                    fullfile(fn,'measurement.csv'));
            end
        end
        
        function saveSegmentation(app, obj, fn)
        %Saves the array with the segmentation labels to a .nii file
        %Input:
        %   obj 	- the userObject with the segmentation to be saved
        %   fn      - name of the .nii output file
            
            outFn   = fullfile(fn,...
                        [obj.name, '-segmentation.nii']);
            nii     = IOUtils.arr2nii(app, obj);
%             nii     = IOUtils.PermuteFlip(nii);
            try
                save_nii(nii, outFn);
            catch err
                uialert(uifigure,err.message,...
                    'Unable to save segmentation');
            end             
        end
        
        function saveObjProperties(properties, fn)
        %Creates a table with all the properties stored in the segmentation
        %of the current image and writes it to an .xlsx file
        %Input:
        %   properties, a cell array with the properties of the objects
        %   filename, the name of the .xlsx file
        %
            %Create table of the segmentation properties
            %get names of properties
            prop    = properties{1};
            varLst  = fieldnames(prop);

            %store properties in cell array
            cellArr = cell(length(properties), numel(varLst));
            for idx = 1:length(properties)
                prop    = properties{idx};    

                for varIdx  = 1:numel(varLst)
                    var     = varLst{varIdx};
                    cellArr{idx, varIdx} = prop.(var);
                end
            end
            %write cellarray to table
            tab = cell2table(cellArr, 'VariableNames', varLst);
            
            %write to disk
%             writetable(tab,filename,'Sheet',1,'Range','A1');
            writetable(tab, fn)
        end
        
        function saveSegmentationPoints(obj, fn)
            %Saves the roiPoints to a json object.
            
            outFn   = fullfile(fn,...
                        [obj.name, '-segmentation.json']);
            
            jsonObj     = struct('points', obj.points);
            txt         = jsonencode(jsonObj);
            
            fid         = fopen(outFn, 'w');
            fwrite(fid, txt, 'char');
            fclose(fid);
        end
        
        function LoadUserObjects(app, idx)
            %Loads userobjects from the disk that correspond to the image
            %at idx.
            folder      = app.AvailableimagesListBox.Items{idx};
            
            if strcmp(folder(1:2), '* ')
                    folder = folder(3:end);
            end
            
            if isa(app.user_profile, 'cell')
                direc       = fullfile(app.current_folder, folder, app.user_profile{1});
            else
                direc       = fullfile(app.current_folder, folder, app.user_profile);
            end
            
            %First find any segmentations
            segFiles    = dir(fullfile(direc,'*.json'));
            for file = segFiles'
%                 jsonFn  = strrep(file.name,'.nii', '.json');
%                 if exist(fullfile(direc,jsonFn),'file')
                IOUtils.loadSegmentationPoints(...
                    app, fullfile(direc,file.name), idx);
%                 else
%                     IOUtils.LoadSegmentation(...
%                         app, fullfile(direc, file.name), idx);
%                 end
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
            nii     = load_nii(fn);
%             nii     = IOUtils.PermuteFlip(nii);
            nii.img = nii.img(:,:,:,1); 
            
            beginPos    = strfind(fn,filesep);
            beginPos    = beginPos(end);
            endPos      = strfind(fn,'-');
            endPos      = endPos(end);
            name        = fn(beginPos + 1 : endPos - 1);
            
            Objects.AddNewUserObj(app,...
                    "type", 1, ...
                    "data", nii.img,...
                    "name", name,...
                    "imageIdx", idx) 
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
            
            %TODO: more elegantly
            beginPos    = strfind(fn,filesep);
            beginPos    = beginPos(end);
            endPos      = strfind(fn,'-');
            endPos      = endPos(end);
            name        = fn(beginPos + 1: endPos - 1);
            
            points = data.points;
            points(any(isnan(points),2),:) = [];

            Objects.AddNewUserObj(app,...
                    "type", 1, ...
                    "data", ROI.PointsToMask(app, points, idx),...
                    "points", data.points,...
                    "name", name,...
                    "imageIdx", idx);
        end
        
        function LoadMeasurements(app, name, idx)
        %Load all the measurements from the disk            
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
        
%         function LoadSet(app)
%         %Prepares a new database
%             Database.PrepareDatabase(app) 
%         end
        
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
            app.filepath = fp;
            
            %Convert files to nii (if needed), find original filenames and
            %set the 'current_folder' object.
            
            IOUtils.findRmsstudioDir(app, fp) %Find the path to rmsstudio
            try
                IOUtils.convertToNii(app);
                app.UIFigure.Name   = ['RMSStudio ' app.current_folder];
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
        %Goes over all nii files in the current folder. When they are 
        %already processed (.rmsstudio_reslice.nii), adds them to the file
        %list. If not, preprocesses them.
                        
            files = dir(fullfile(app.current_folder,...
                '*.nii'));
            
            app.AvailableimagesListBox.Items = {};
            
            counter = 1;
            for file_id=1:length(files)
                text        = files(file_id).name; 
                if contains(text, '.rmsstudio_reslice.nii')
                    app.AvailableimagesListBox.Items{counter} = ...
                        erase(text, '.rmsstudio_reslice.nii');
                    counter = counter + 1;
                else
                    %skip for now
                    
                    continue
                    
                    
                    %if no _reslice version exists, reslice
                    reslice_path = fullfile(app.current_folder,...
                        strrep(text,'.nii','.rmsstudio_reslice.nii'));
                    if exist(reslice_path,'file')
                        continue
                    end
                    
                    current_path = fullfile(app.current_folder, text);
                    IOUtils.ResliceResampleNii(current_path, reslice_path)
                    app.AvailableimagesListBox.Items{counter} = ...
                        erase(text, '.nii');
                    counter = counter + 1;
                end
            end       
        end
        
        function convertToNii(app)
            %If no previous conversions exist, Create a rmsstudio 
            %directory with .nii versions of all the files using dcm2nii.
                
            if(numel(dir(app.current_folder)) == 2)
                %If folder exists, but is emtpy, try to load dicom images.
                %only elements in folder are '.' & '..'
                dcm2nii = IOUtils.checkDcm2Nii();
                if isempty(dcm2nii)
                    return
                end
                cmd = [dcm2nii ' -f %d_%s -o "'                     ...
                        app.current_folder '" "'  app.filepath '"'];
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
            nii.img = permute(nii.img,[2 1 3 4]);
            nii.hdr.dime.dim([2,3]) = nii.hdr.dime.dim([3,2]);
        
        end
        
        function findRmsstudioDir(app, fp)
            %Searches the current workspace for a dir that includes 
            %'rmsstudio' in its name. Sets this as app.current_folder.
            %If no such folder exists, one is made.
            app.current_folder = [];
            
            %If the path already contains the rmsstudio folder, return
            if contains(fp, 'rmsstudio')
                app.current_folder = fp;
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
               
               app.current_folder = fullfile(item.folder, item.name); 
               break
            end
            
            %Doesn't exist, make the folder
            if isempty(app.current_folder)
                mkdir(fullfile(fp,'rmsstudio'))
            end
            
        end
        
    end
   
end