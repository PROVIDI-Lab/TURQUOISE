classdef imDiffPlugin   
    properties
        app     % pointer to the TURQUOISE app.
    end

    methods (Access = public)
        function obj = imDiffPlugin(app)    %rename 
            obj.app = app;  %initialize the app
            
            %You can add more code here, but this will all be run on app
            %startup, so no images etc are loaded.
        end

        function Excecute(obj) %runs when the plugin is selected from the menu
            %Prompt the user for two image targets

            targets = Interaction.PromptTarget(obj.app, true);

            %check whether exactly two images are selected
            if length(targets) ~= 2
                errordlg("Please select exactly two images")
                return
            end

            %For each image, check if already loaded. Load if not
            if isempty(obj.app.data{targets(1)})
                IOUtils.LoadNii(obj.app, targets(1))
            end
            if isempty(obj.app.data{targets(2)})
                IOUtils.LoadNii(obj.app, targets(2))
            end

            %Check if the two images have the same size
            if any(size(obj.app.data{targets(1)}.img) ~= ...
                size(obj.app.data{targets(2)}.img))
                errordlg("Images should be the same size")
                return
            end

            %Calculate the difference
            imDiff = abs(obj.app.data{targets(1)}.img ...
                - obj.app.data{targets(2)}.img);

            %Use one of the earlier images to create the new nii file
            out_nii = obj.app.data{targets(1)};
            out_nii.img = imDiff;
            
            %Flip to go from Matlab coordinates to 'normal' coordinates
            out_nii = NiftiUtils.FlipPermute(out_nii);

            %Get the names of the target images to create a new name
            im1Name = obj.app.sessionNames{targets(1)};
            im2Name = obj.app.sessionNames{targets(2)};
            out_name = ['Diff_' im1Name '-' im2Name '.nii.gz'];

            %Get the current folder path to create the output path
            out_path = fullfile(obj.app.sessionPath, out_name);

            %Write the new image
            save_untouch_nii(out_nii, out_path)

            %Reload the study
            IOUtils.PrepareStudy(obj.app, obj.app.sessionPath)

        end
    end

    methods (Access = private)
        %Add any sub-functions here.

    end
       
end