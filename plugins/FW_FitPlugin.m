classdef FW_FitPlugin   
    properties
        app     % pointer to the TURQUOISE app.
    end

    methods (Access = public)
        function obj = FW_FitPlugin(app)    
            obj.app = app;  %initialize the app
            
            %You can add more code here, but this will all be run on app
            %startup, so no images etc are loaded.
        end

        function Excecute(obj) %runs when the plugin is selected from the menu
            
            targets = Interaction.PromptTarget(obj.app, true);
            if isempty(targets)
                return
            end

            GUI.DisableControlsStatus(obj.app, "Loading, please wait", 'on')

            %Loop over each image
            for i = 1:length(targets)

                target = targets(i);
                %check if already loaded. Load if not
                if isempty(obj.app.data{targets(i)})
                    IOUtils.LoadNii(obj.app, target)
                end

                %get target fn
                targetName = obj.app.sessionNames{target};
                targetFn = fullfile(obj.app.sessionPath, [targetName '.nii.gz']);
                
                %get bval & bvec fns
                bvalFn = strcat(targetName, '.bval');
                bvecFn = strcat(targetName, '.bvec');
                bvalFn = fullfile(obj.app.sessionPath, bvalFn);
                bvecFn = fullfile(obj.app.sessionPath, bvecFn);

                %find bvals
                bvals = sort(load(bvalFn));

                %prompt mask
                mask = Interaction.PromptMask(obj.app, false, targetName);
                if isempty(mask)
                    errordlg("No mask found.")
                    return
                end
                maskFn = fullfile(obj.app.sessionPath, ...
                    obj.app.sessionNames{target}, mask);

                MRTQuant.PerformSpectralDeconvolution( ...
                    'nii_file', targetFn, ...
                    'bval_file', bvalFn, ...
                    'bvec_file', bvecFn, ...
                    'mask_file', maskFn, ...
                    'min_bval', min(bvals), ...
                    'max_bval', max(bvals), ...
                    'output', fullfile(obj.app.sessionPath, [targetName '_FW']))
            end

            GUI.RevertControlsStatus(obj.app)

        end
    end

    methods (Access = private)
        %Add any sub-functions here.

    end
       
end