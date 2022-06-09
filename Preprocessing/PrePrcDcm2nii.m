classdef PrePrcDcm2nii < handle
    methods (Static)

        function Start(app)

            %Find dcm2nii location
            dcm2nii = PrePrcDcm2nii.checkDcm2nii();

            if isempty(dcm2nii)
                errordlg("Invalid dcm2nii location.")
                return
            end

            d = uiprogressdlg(app.UIFigure, 'Title','Converting DCMs');

            if app.MultipleimagesCheckBox.Value

                folders = dir(app.filepath);
                folders = folders(~ismember({folders.name},{'.','..'}));

                for i = 1:length(folders)
                    folder = folders(i);

                    if ~folder.isdir
                        continue
                    end

                    mkdir(fullfile(...
                        app.outpath, folder.name))

                    d.Value = i/length(folders);
                    d.Message = ['Folder ' num2str(i) ...
                        ' out of ' num2str(length(folders))];
                    PrePrcDcm2nii.convertFolder(app, folder.name, dcm2nii)
                end
            else
                PrePrcDcm2nii.convertFolder(app, '', dcm2nii)
            end

            close(d);

        end

        function convertFolder(app, name, dcm2nii)
            cmnd = dcm2nii;
           
            if app.SeriesinnameCheckBox.Value
                if app.DescriptioninnameCheckBox.Value
                    cmnd = [cmnd ' -f %d_%s '];
                else
                    cmnd = [cmnd ' -f %s '];
                end
            end

            if app.PhilipsprecisefloatCheckBox.Value
                cmnd = [cmnd '-p n '];
            end

            out = fullfile(app.outpath, name);
            in = fullfile(app.filepath, name);

            cmnd = [cmnd '-o "' out  '" "' in '"'];
            system(cmnd);
        end

        function dcm2nii = checkDcm2nii()
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




    end
end