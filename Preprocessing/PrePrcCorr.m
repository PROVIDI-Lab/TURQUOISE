classdef PrePrcCorr < handle
    methods (Static)

        function Start(app)

            %Progress window
            d = uiprogressdlg(app.UIFigure, 'Title',...
                'Applying corrections - this might take a while');

            %Either process multiple folders, or a single one
            if app.MultipleimagesCheckBox.Value

                folders = dir(app.filepath);
                folders = folders(~ismember({folders.name},{'.','..'}));

                for i = 1:length(folders)
                    folder = folders(i);

                    if ~folder.isdir
                        continue
                    end
                    
                    %create output subfolder
                    mkdir(fullfile(...
                        app.outpath, folder.name))

                    d.Value = i/length(folders);
                    message = ['Folder ' num2str(i) ...
                        ' out of ' num2str(length(folders))];

                    PrePrcCorr.CorrFolder(app, folder.name, d, message)
                end
            else
                %single folder
                message = ['Folder 1 out of 1'];
                PrePrcCorr.CorrFolder(app, '', d, message)
            end

            close(d);
        end


        function CorrFolder(app, folder, d, msg)

            %create temp folder for processing;
            tmp_dir = fullfile(app.outpath, folder, 'temp');
            mkdir(tmp_dir)

            %Find all files that need correcting
            bvalfiles = dir(fullfile(app.filepath, folder, '*.bval'));
            if isempty(bvalfiles)
                errordlg(['No .bval files found. Make sure they are' ...
                    'present in the folder with the .nii files.' ...
                    'Rerun dcm2nii if needed.']);
                rmdir(tmp_dir, 's')
                return
            end

            %Go over all files, apply processing individually
            for i= 1 : length(bvalfiles)
                bvalfile = bvalfiles(i);
                bvalfile = fullfile(bvalfile.folder, bvalfile.name);
                PrePrcCorr.ProcessFile(app, bvalfile,...
                    tmp_dir, folder, d, msg)
            end

            %remove tmp files
            rmdir(tmp_dir, 's')

        end


        function FlipT1(app)
            [~, anatName, ~] = fileparts(app.t1_path);

            EDTI.FlipPermuteSpatialDimensions('nii_file', ...
                app.t1_path, ...
                'output', ...
                fullfile(tmp_dir, [anatName '_FP.nii']) )
        end

        function ProcessFile(app, bvalfile, tmp_dir, folder, d, msg)


            %First check if the data is usable
            if ~PrePrcCorr.CheckBvals(bvalfile)
                d.Message = 'bvals not useful. Skipping.';
                return
            end

            %Create paths for in&output
            [in_path,name,~] = fileparts(bvalfile);
            out_path = fullfile(app.outpath, folder);

            %Creat b-matrix
            b_mat_out = fullfile(tmp_dir, [name '.txt']);
            EDTI.b_Matrix_from_bval_bvec( ...
                'bval_file', ...
                bvalfile,...
                'output', ...
                b_mat_out);

            tmp_file = fullfile(tmp_dir, [name, '_tmp.nii']);

            %Flip
            flip_in = fullfile(in_path, [name '.nii']);
            EDTI.FlipPermuteSpatialDimensions( ...
                'nii_file', ...
                flip_in, ...
                'output', ...
                tmp_file, ...
                'flip', ...
                [0 1 0]);

            if app.DenoiseCheckBox.Value
                m_new = [msg ' - Performing denoising'];
                d.Message = m_new;

                MRTD.PerformMPPCADenoising( ...
                    'nii_file', ...
                    tmp_file, ...
                    'output', ...
                    strrep(tmp_file, '.nii', ''))

                tmp_file = strrep(tmp_file, '.nii', '_denoised.nii');
            end

            if ~app.DKIDTIfitCheckBox.Value
                %save denoised file to output

                return
            end

            
            %Perform DKI/DTI fit
            m_new = [msg ' - Fitting DTI/DKI'];
            d.Message = m_new;

            EDTI.PerformDTI_DKIFit( ...
                'nii_file', ...
                tmp_file, ...
                'grad_perm', 2, 'grad_flip', 2,...
                'txt_file', ...
                b_mat_out)

            if app.MotionEddycorrectionCheckBox.Value

                m_new = [msg ' - Performing motion correction'];
                d.Message = m_new;

                EDTI.PerformMocoEPI( ...
                    'mat_file', ...
                    strrep(tmp_file, '.nii', '.mat'),...
                    'fit_mode','wls');
            end


            if app.MotionEddycorrectionCheckBox.Value
                mat_fn = strrep(tmp_file, '.nii', '_MD_C_native.mat');
            else
                mat_fn = strrep(tmp_file, '.nii', '.mat');
            end
            
            if app.SaveasniiCheckBox.Value
%                 EDTI.MatMetrics2Nii(mat_fn);
                
                if app.SaveFACheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_FA.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_FA.nii']);
                    movefile(fn, out_fn)
                end
                if app.SaveFECheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_FE.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_FE.nii']);
                    movefile(fn, out_fn)
                end
                if app.SaveL1CheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_L1.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_L1.nii']);
                    movefile(fn, out_fn)
                end
                if app.SaveMDCheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_MD.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_MD.nii']);
                    movefile(fn, out_fn)
                end
                if app.SaveFA_abs_FECheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_FA_abs_FE.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_FA_abs_FE.nii']);
                    movefile(fn, out_fn)
                end
                if app.SaveRDCheckBox.Value
                    suffix  = '_tmp_denoised_MD_C_native_RD.nii';
                    fn      = fullfile(tmp_dir, [name suffix]);
                    out_fn  = fullfile(out_path, [name '_RD.nii']);
                    movefile(fn, out_fn)
                end


            else
                out_fn = fullfile(...
                out_path,[name '_processed.mat']);
                movefile(mat_fn, out_fn)            
            end



        end

        function cont = CheckBvals(file)
            fid = fopen(file, 'r');
            bvals = fscanf(fid, '%f');
            if length(unique(bvals)) <= 1
                cont = false;
            else
                cont = true;
            end
        end



    end
end