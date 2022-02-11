classdef PrePrcDcm2nii < handle
    methods (Static)

        function Start(app)

            %Find dcm2nii location
            dcm2nii = PrePrcDcm2nii.checkDcm2nii();

            if isempty(dcm2nii)
                errordlg("Invalid dcm2nii location.")
                return
            end

            d = uiprogressdlg(app.UIFigure, 'Title','Converting Dicoms',...
                'Indeterminate','on');


            cmnd = dcm2nii;
            if app.DescriptioninnameCheckBox.Value
                cmnd = [cmnd ' -f %d '];
            end

            if app.SeriesinnameCheckBox.Value
                if app.DescriptioninnameCheckBox.Value
                    cmnd = [cmnd '_%s '];
                else
                    cmnd = [cmnd '-f %s '];
                end
            end

            if app.PhilipsprecisefloatCheckBox.Value
                cmnd = [cmnd '-p n '];
            end

            cmnd = [cmnd '"' app.outpath  '" "' app.filepath '"'];
            system(cmnd);

            close(d);

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