classdef IOUtils < handle

    methods (Static)
        
        % After nifti import
        function [nii, ratio] = RMSStandardVolumeTreatment(nii)
            min_vs = min(nii.hdr.dime.pixdim(2:1+ndims(nii.img)));
            tic
            [nii.img, ratio] = MathUtils.ResampleVolume(nii.img,        ...
                               nii.hdr.dime.pixdim(2:4), ...
                               min_vs*ones(1,3));
            toc
            nii.img = permute(nii.img,[2 1 3 4]);
            disp('Also permuted');
            nii.img = flip(nii.img,1);
            nii.img = flip(nii.img,2);
            nii.img = flip(nii.img,3);
        end
        
        % Before save
        function [nii, ratio] = RMSStandardVolumeDetreatment(nii)        
            nii.img = single(nii.img);
            nii.hdr.dime.dim(1) = 3;
            nii.hdr.dime.dim(5) = 1;
            nii.img = permute(nii.img,[2 1 3]);
            nii.img = flip(nii.img,1);
            nii.img = flip(nii.img,2);
            nii.img = flip(nii.img,3);
            min_vs = min(nii.hdr.dime.pixdim(2:1+ndims(nii.img)));
            nii.img, ratio = MathUtils.ResampleVolume(nii.img,          ...
                               min_vs*ones(1,3),                        ...
                               nii.hdr.dime.pixdim(2:4));
        end 
        
        function ResliceResampleNii(app, index)
        %Loads the .rmsstudio_reslice.nii file associated with the current
        %image. Sets the nii file as the current image.
        %Input: 
        %app, the RMSStudio app
        %Index, the index of the image currently being loaded
            
            fp = app.current_folder;
            fn = app.AvailableimagesListBox.Items{index};
            reslice_name = fullfile(fp,[fn(1:end-4)             ...
                                        '.rmsstudio_reslice.nii']);
        
            %If the file doesn't exist, reslice it now.
            if(exist(reslice_name,'file') < 1)
                hdr = load_untouch_header_only(fullfile(fp,fn));
                reslice_nii(fullfile(fp,fn),                    ...
                            reslice_name,                       ...
                            hdr.dime.pixdim(2:4));
                        
                %Resample file
                nii     = load_nii(reslice_name);
                [nii, ratio] = IOUtils.RMSStandardVolumeTreatment(nii);
                
                %change header
                nii.hdr.dime.dim(2:1+ndims(nii.img)) = size(nii.img);
                nii.hdr.dime.pixdim(2:4) = nii.hdr.dime.pixdim(2:4)     ...
                                            ./ ratio;
                
                %Save back to disk
                save_nii(nii, reslice_name);
            end
        end   
        
        function LoadNii(app, index)
        %Loads the .rmsstudio_reslice.nii file associated with the current
        %image. Sets the nii file as the current image.
        %Input: 
        %   app, the RMSStudio app
        %   Index, the index of the image currently being loaded
        
            fp = app.current_folder;
            fn = app.AvailableimagesListBox.Items{index};
            reslice_name = fullfile(fp,[fn(1:end-4)             ...
                                        '.rmsstudio_reslice.nii']);
            
            %Load the file
%             reslice_name    = convertCharsToStrings(reslice_name);
            nii     = load_nii(reslice_name);
            nii.img = single(nii.img);
            
%             app.data_list(index)    = {nii};
            app.data                = nii;
            app.current_4d_idx      = 1;
            app.DSlider.Value       = 1;
        
        end
        
        function saveSegmentations(nii, fn)
        %Saves the array with the segmentation labels to a .nii file
        %Input:
        %   nii - the segmentation to be saved
        %   fn  - name of the .nii output file
        
            try
                save_nii(nii, fn);
            catch err
                uialert(uifigure,err.message,'Unable to save segmentation');
            end             
        end
        
        
        function saveSegmentationProperties(segmentation, filename)
        %Creates a table with all the properties stored in the segmentation
        %of the current image and writes it to an .xlsx file
        %Input:
        %   segmentation - the segmnetation item with all the properties
        %   filename, the name of the .xlsx file
        %
        
            %Create table of the segmentation properties
            %get names of properties
            prop  = segmentation.properties{1};
            nameLst = {length(prop)};
            for propIdx = 1:length(prop)
                nameLst{propIdx} = prop{propIdx}{1};
            end

            %store properties in cell array
            cellArr = {length(segmentation.properties), length(prop)};
            for idx = 1:length(segmentation.properties)
                prop    = segmentation.properties{idx};    

                for propIdx = 1:length(prop)
                    cellArr{idx, propIdx} = prop{propIdx}{2};
                end
            end
            %write cellarray to table
            tab = cell2table(cellArr, 'VariableNames', nameLst);
            
            %write to disk
%             writetable(tab,filename,'Sheet',1,'Range','A1');
            writetable(tab, filename)
        end
        
        function saveSegmentationPoints(points, idx, filename)
            %Saves the roiPoints and roiPointIndex to a json object.
            
            obj     = struct('points', points, 'index', idx);
            txt     = jsonencode(obj);
            
            fid     = fopen(filename, 'w');
            fwrite(fid, txt, 'char');
            fclose(fid);
            
            
        end
        
        %Creates a table with all the properties stored in the measurements
        %of the current image and writes it to an .xlsx file
        function saveMeasurementProperties(app, image_id)
            fn          = app.AvailableimagesListBox.Items{image_id};
            names       = app.measure_names_list{image_id};
            filename    = fullfile(app.current_folder,                  ...
                               [fn(1:end-4)                             ...
                                app.user_profile{1}                     ...
                                '-measurements.csv']);
            measurements    = app.measurement_list{image_id};
            lengths         = app.measure_length_list{image_id};
            
            %Preallocate new cell array            
            cellArr = {round(size(measurements,1)/2)};

            %add measurements to cell array
            for line_id = 1 : 2 : size(measurements,1)
                
                    
                P1  = measurements(line_id, :);
                P2  = measurements(line_id + 1, :);
                
                cellArr{round(line_id/2),1} = names{round(line_id/2)};
                cellArr{round(line_id/2),2} = lengths(round(line_id/2));
                cellArr{round(line_id/2),3} = P1;
                cellArr{round(line_id/2),4} = P2;
                
            end
            %write cellarray to table
            tab = cell2table(cellArr,                                   ...
                             'VariableNames',                           ...
                             {'Measurement', 'Length', 'P1', 'P2'});
            
            %write to disk
%             writetable(tab,filename,'Sheet',2,'Range','A1');
            writetable(tab, filename);
                
        end
        
        function LoadSegmentation(app, name)
            
            index = app.current_image_idx;
            
            if(exist(name,'file') > 0)
                nii     = load_nii(name);
                nii.img = nii.img(:,:,:,1); 
%                 % FIx app.ResampleVolume to be 4D compatible
%                 nii     = IOUtils.RMSStandardVolumeTreatment(nii);

                app.segmentation_list{index}        = nii;
                app.seg_names_list{index}           = {};
                IOUtils.LoadSegmentationProperties(app, name)     
            else
                app.segmentation_list{index}        = [];
                app.seg_names_list{index}           = {};
            end
        end
        
        function LoadSegmentationProperties(app, name)
            
            index = app.current_image_idx;
            
            propfn  = [name(1:end-4) '.csv'];
            table   = readtable(propfn);
            
            for line_id = 1:size(table,1)
                
                app.seg_names_list{index}(end+1)    = table.Name(line_id);
                
                
                app.segmentation_list{index}.properties{line_id}{1} =   ...
                    {'Name', table.Name{line_id}};
                app.segmentation_list{index}.properties{line_id}{2} =   ...
                    {'Volume', table.Volume(line_id)};
                app.segmentation_list{index}.properties{line_id}{3} =   ...
                    {'Mean', table.Mean(line_id)};
                app.segmentation_list{index}.properties{line_id}{4} =   ...
                    {'Max', table.Max(line_id)};
                app.segmentation_list{index}.properties{line_id}{5} =   ...
                    {'Min', table.Min(line_id)};
                app.segmentation_list{index}.properties{line_id}{6} =   ...
                    {'Std', table.Std(line_id)};
                app.segmentation_list{index}.properties{line_id}{7} =   ...
                    {'perc25', table.perc25(line_id)};
                app.segmentation_list{index}.properties{line_id}{8} =   ...
                    {'perc50', table.perc50(line_id)};
                app.segmentation_list{index}.properties{line_id}{9} =   ...
                    {'perc75', table.perc75(line_id)};
            end
        end
        
        function loadSegmentationPoints(app, name)
           %Loads the points stored in the -segmentation.json file 
           %associated with the current image.
           
           index = app.current_image_idx;
            
           if(exist(name,'file') > 0)
               fid  = fopen(name, 'r');
               txt  = fread(fid,inf);
               txt  = char(txt');
               fclose(fid);
               
               data = jsondecode(txt);

               app.roiPointList{index}      = data.points;
               app.roiPointIndexList{index} = data.index;
            else
               app.roiPointList{index}      = [];
               app.roiPointIndexList{index} = [];
            end
           
        end
        
        function LoadMeasurements(app, name)
            %..
            
            index = app.current_image_idx;
            
            if(exist(name,'file') > 0)
                
                %preallocate measurement_lines
                app.drawing.measurement_lines  = [];
                
                %Read measurement from .xlsx file
                table = readtable(name);
                
                msrmnt_list = [];
                name_list   = [];
                length_list = [];
                for line_id = 1:size(table,1)
                    P11     = table.P1_1(line_id);
                    P12     = table.P1_2(line_id);
                    P13     = table.P1_3(line_id);
                    P21     = table.P2_1(line_id);
                    P22     = table.P2_2(line_id);
                    P23     = table.P2_3(line_id);
                    
                    length      = table.Length(line_id);
                    name        = table.Measurement(line_id);
                    msrmnt_list = [msrmnt_list;                        ...
                                   [P11, P12, P13; P21, P22, P23]];
                    name_list   = [name_list; name];     
                    length_list = [length_list; length];
                end
                
                %Add to app
                app.measurement_list{index}     = msrmnt_list;
                app.measure_names_list{index}   = name_list;
                app.measure_length_list{index}  = length_list;
                
            else
                app.measurement_list{index}     = [];
                app.measure_names_list{index}   = [];
                app.measure_length_list{index}  = [];
            end
        end
        
        function LoadSet(app)
        %Prepares a new database
            Database.PrepareDatabase(app) 
        end
        
        function PrepareStudy(app, filepath)
        %Prepares a new study when the 'Load' button is pressed.
        %First checks if the Study has already been processed (contains a
        %.rmsstudio folder). If so, loads all items from that folder. If no
        %previously processed folder exists, or if the .rmsstudio folder is
        %empty, it converts any dicom images to nii standard.
                    
            if ~exist('filepath','var')
                fp = uigetdir('Select a subject folder');
                if(isnumeric(fp) && fp == 0)
                    app.UIFigure.Visible = 'on';
                    return
                end
            else
                fp              = filepath;
            end
            app.filepath    = fp;
        
            app.UIFigure.Visible = 'off';
            GUI.DisableControlsStatus(app);
            pause(0.01);
            drawnow
            h = waitbar(0,'Please wait');
            
            
            %Convert files to nii (if needed), find original filenames and
            %set the 'current_folder' object.
            try
                previously_processed = fullfile(fp,'.rmsstudio');
                IOUtils.convertToNii(fp, previously_processed);
                
                %Find all original files (nothing created by rmsstudio 
                %itself. 
                IOUtils.getFilenames(app, previously_processed);
                
                app.current_folder  = previously_processed;
                app.UIFigure.Name   = ['RMSStudio ' app.current_folder];
            catch err
                close(h);
                uialert(uifigure,err.message,'');
                app.UIFigure.Visible = 'on';
                GUI.RevertControlsStatus(app);
            end
            
            try
                close(h)
                app.UIFigure.Visible = 'on';
            catch 
            end
            
            
            %Reslice and resample all nii files
            for idx = 1:length(app.AvailableimagesListBox.Items)
                IOUtils.ResliceResampleNii(app, idx)
            end          
            
            %Initialises the study objects
            Study.InitStudy(app)
            
        end
        
        function getFilenames(app, previously_processed)
            files = dir(fullfile(previously_processed,'*.nii'));
                good_files = true(size(files));
                for file_id=1:length(good_files)
                    if(contains(files(file_id).name,'rmsstudio') || ...
                       contains(files(file_id).name,'localizer') || ...
                       contains(files(file_id).name,'segmentation'))
                        good_files(file_id) = false;
                    end
                end
                files = files(good_files);
                
                %Add files to selection box in UI
                app.AvailableimagesListBox.Items = {};
                for file_id=1:length(files)
                    text        = files(file_id).name;
                    app.AvailableimagesListBox.Items{file_id} = text;
                end
        end
        
        function convertToNii(fp, previously_processed)
            %If no previous conversions exist, Create a .rmsstudio 
            %directory with .nii versions of all the files using dcm2nii.
            
            if(exist(previously_processed,'dir') < 1) 
                dcm2nii = IOUtils.checkDcm2Nii();
                mkdir(previously_processed);
                cmd = [dcm2nii ' -f %p_%s -o "'                     ...
                        previously_processed '" "'  fp '"'];
                system(cmd);
                
            elseif(numel(dir(previously_processed)) == 2)
                %If folder exists, but is emtpy, also try to load new
                %dicom images.
                %only elements in folder are '.' & '..'
                dcm2nii = IOUtils.checkDcm2Nii();
                cmd = [dcm2nii ' -f %p_%s -o "'                     ...
                        previously_processed '" "'  fp '"'];
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
%                 warning("Matlab can't find dcm2nii on its path.")
%                 return

            %For dev. only
                addpath('C:\dMRI\Matlab_Libs\dcm2nii')
                dcm2nii     = 'C:\dMRI\Matlab_Libs\dcm2nii\dcm2niix';
            end
            
        end
        
    end
   
end