classdef NewDatasetUtils < handle
    methods (Static)

        function status = ConvertDcm2Nii(app)

            status = 1; %check if the operation continues well

            %Look for dcm & nii files
            msg = sprintf('Looking for Nifti files.');
            app.dlg.Message = msg;
            app.dlg.Value =  0 / 2;
            niiFiles = dir(fullfile(app.fp, '**\*.nii.gz'));
            msg = sprintf('Looking for Dicom files.');
            app.dlg.Message = msg;
            app.dlg.Value =  1 / 2;
            dcmFiles = dir(fullfile(app.fp, '**\*.dcm'));
            app.dlg.Value =  2 / 2;

            if isempty(niiFiles)
                if isempty(dcmFiles)
                    selection = uiconfirm(app.UIFigure, ...
                        "No .dcm files found. Continue anyway?", ...
                        "File error", "Icon","warning");
                    if strcmp(selection, "Cancel")
                        status = 0;
                        return
                    end
                end
            else    %no need to convert
                return
            end

            %Find dcm2nii location
            dcm2nii = NewDatasetUtils.FindDcm2nii();

            if isempty(dcm2nii)
                errordlg("Invalid dcm2nii location.")
                status = 0;
                return
            end

            %Go over patient folders
            pidFolders = dir(app.fp);
            pidFolders = pidFolders(~ismember({pidFolders.name},{'.','..'}));


            for i = 1:length(pidFolders)
                pFolder = pidFolders(i);

                if ~pFolder.isdir
                    continue
                end

                %Find all session folders 
                sessionFolders = dir(fullfile(...
                    pFolder.folder, pFolder.name));
                sessionFolders = sessionFolders(...
                                ~ismember({sessionFolders.name},...
                                {'.','..'}));

                for j = 1:length(sessionFolders)
                    sFolder = sessionFolders(j);
                    if ~sFolder.isdir
                        continue
                    end
                    inpath = fullfile(sFolder.folder, sFolder.name);
                    outpath = fullfile(inpath, 'rmsstudio');
                    mkdir(outpath)
    
                    app.dlg.Value = (i-1)/length(pidFolders) + ...
                        j/length(sessionFolders)/length(pidFolders);
                    msg = ['Converting Dicoms, folder '...,
                        num2str(i) ' / ' num2str(length(pidFolders)),...
                        ' - ' pFolder.name, ' - ', sFolder.name];
                    app.dlg.Message = msg;
                    NewDatasetUtils.convertFolder(inpath, outpath, dcm2nii)
                end
            end

            app.dlg.Value = 1;
        end

        function convertFolder(inpath, outpath, dcm2nii)
            cmnd = dcm2nii;
            cmnd = [cmnd ' -f %d_%s ']; %add series & description
            cmnd = [cmnd '-p n '];      %philips precise float - no
            cmnd = [cmnd '-z y '];      %compress -> nii.gz

            out = fullfile(outpath);
            in = fullfile(inpath);

            cmnd = [cmnd '-o "' out  '" "' in '"'];
            system(cmnd);
        end

        function dcm2nii = FindDcm2nii()
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

                if exist(dcm2nii, 'file')
                    msgbox(strcat("Found dmc2niix at: ", dcm2nii))
                else
                    msgbox("didn't find dcm2niix, please try again")
                    dcm2nii = NewDatasetUtils.FindDcm2nii();
                end

            end
            
        end


        function status = ResliceNiis(app)

            status = 1;

            msg = sprintf('Looking for Nifti files.');
            app.dlg.Message = msg;
            app.dlg.Value =  0;
            niiFiles = dir(fullfile(app.fp, '**\*.nii.gz'));
            should_reslice = [];

            %Check each nii for reslicing
            for i = 1:length(niiFiles)
                app.dlg.Message = ['Checking Nifti header '...,
                    num2str(i) ' / ' num2str(length(niiFiles))];
                app.dlg.Value =  i / length(niiFiles);

                fn = fullfile(niiFiles(i).folder, niiFiles(i).name);
                hdr = load_nii_hdr(fn);
                if NewDatasetUtils.checkNiiHdr(hdr)
                    should_reslice{end+1} = fn;
                end
            end

            %Reslice niis
            for i = 1:length(should_reslice)
                app.dlg.Message = ['Reslicing Nifti '...,
                    num2str(i) ' / ' num2str(length(should_reslice))];
                app.dlg.Value =  (i-1) / length(should_reslice);
                
                %Overwrite previous nii
                reslice_nii(should_reslice{i}, should_reslice{i})
            end
            app.dlg.Value =  1;

        end

        function shouldReslice = checkNiiHdr(hdr)
            shouldReslice = 0;
            tolerance = 0.1;
            
            if isequal(hdr.hist.sform_code,0)
               error('User requires sform, sform not set in header');
            end
            
            R = [hdr.hist.srow_x(1:3)
               hdr.hist.srow_y(1:3)
               hdr.hist.srow_z(1:3)];
            
            T = [hdr.hist.srow_x(4)
               hdr.hist.srow_y(4)
               hdr.hist.srow_z(4)];
            
            if det(R) == 0 | ~isequal(R(find(R)), sum(R)')
                hdr.hist.old_affine = [ [R;[0 0 0]] [T;1] ];
                R_sort = sort(abs(R(:)));
                R( find( abs(R) < tolerance*min(R_sort(end-2:end)) ) ) = 0;
                hdr.hist.new_affine = [ [R;[0 0 0]] [T;1] ];
            
                if det(R) == 0 | ~isequal(R(find(R)), sum(R)')
                shouldReslice = 1;
                end
            end
        end


        function status = ComputeADCMaps(app)
            status = 1;

            msg = sprintf('Looking for DWI files.');
            app.dlg.Message = msg;
            app.dlg.Value =  0;

            bvalFiles = dir(fullfile(app.fp, '**\*.bval'));

            for i = 1:length(bvalFiles)
                fn = fullfile(bvalFiles(i).folder, bvalFiles(i).name);
                app.dlg.Message = ['Computing ADC map '...,
                    num2str(i) ' / ' num2str(length(bvalFiles))];
                app.dlg.Value =  (i-1) / length(bvalFiles);
                NewDatasetUtils.DWIConv(fn)
            end
            app.dlg.Value =  1;

        end

        function DWIConv(fn)

            if contains(fn, '.nii')
                %nii input, load nii and create .bvalfile
                nii_fn = fn;
                nii = load_untouch_nii(nii_fn);
                [sx,sy,sz,st] = size(nii.img);

                fn = NewDatasetUtils.makeBvalFile(st, fn);
                bvals = sort(load(fn));

            else    %.bval input

                bvals = sort(load(fn));
    
                nii_fn = strrep(fn, '.bval', '.nii.gz');
                nii = load_untouch_nii(nii_fn);
    
                %check for correct number of b-vals
                [sx,sy,sz,st] = size(nii.img);

                if st == 1 %only 1 bval - can't compute ADC
                    return
                end
    
                if ~NewDatasetUtils.correctBvals(bvals, st)
                    bvals = NewDatasetUtils.getCorrectBvals(st, fn);
                end
            end

            uniqueBVals = unique(bvals);
            X = [-uniqueBVals' ones(length(uniqueBVals),1)];

            %Find background to remove later
            %assumes 1st bval = 0
            %background < 1st %ile
            b0img = nii.img(:,:,:,1);
            prct = prctile(b0img(b0img>0), 5);
            bckGrndIdx = b0img <= prct;

            %init arrays
            out_nii = nii;
            input_img = reshape(nii.img,sx*sy*sz,st);
            
            input_img_avg = zeros(sx*sy*sz, length(uniqueBVals));

            %average duplicate b-vals (we don't care about directionality)
            for i = 1:length(uniqueBVals)
                bval = uniqueBVals(i);                
                avgVals = mean(input_img(:, bvals == bval), 2);
                input_img_avg(:,i) = avgVals;                
            end
            
            %Sort according to bvals
            [~, I] = sort(mean(input_img_avg), 'descend');
            input_img = input_img_avg(:,I);

            %Calculate ADC values based on solving the diffusion equation.

            res = X\log(single(input_img)');
            ADC = res(1,:);
            ADC(isnan(ADC)) = 0;
            ADC(ADC < 0) = 0;
            ADC = reshape(ADC, [sx, sy, sz]);
            ADC(bckGrndIdx) = 0;

            out_nii.hdr.dime.bitpix = 32;
            out_nii.hdr.dime.datatype = 16;
            out_nii.hdr.dime.scl_slope = 1;
            out_nii.hdr.dime.scl_inter = 0;
            out_nii.hdr.dime.dim(1) = 3;
            out_nii.hdr.dime.dim(5) = 1;
            out_nii.img = ADC;

            [folder, name, ~] = fileparts(fn);
            save_untouch_nii(out_nii, fullfile(folder, ['ADC_' name '.nii.gz']))

            %also calculate IVIM, if possible
            if sum(uniqueBVals < 200 & uniqueBVals > 0) < 1 || length(uniqueBVals) < 3
                return %can't do IVIM
            end
            
            IX_high = uniqueBVals >= 200;
            IX_low = uniqueBVals < 200;

            if sum(IX_high) < 2
                IX_high = false(length(uniqueBVals), 1);
                IX_high(end-1:end) = true;
            end
            if sum(IX_low) < 2
                IX_low = false(length(uniqueBVals), 1);
                IX_low(1:2) = true;
            end

            %high
            Xh = [-uniqueBVals(IX_high)' ones(sum(IX_high==1),1)];
	        HighD = Xh\log(input_img(:,IX_high))'; 
            HighD(isnan(HighD)) = 0;
            HighD(HighD < 0) = 0;
            HighD(HighD == inf) = 0;

            %low
            Xl = [-uniqueBVals(IX_low)' ones(sum(IX_low==1),1)]; 
	        LowD = Xl\log(input_img(:,IX_low))';
            LowD(isnan(LowD)) = 0;
            LowD(LowD < 0) = 0;
            LowD(LowD == inf) = 0;

            %f
            f = abs(input_img(:,1) - exp(HighD(2,:)'))./input_img(:,1);
            f(isnan(f)) = 0;
            f(f < 0) = 0;
            f(f == inf) = 0;

            %save
            %high
            HighD = reshape(HighD(1,:), [sx, sy, sz]);
            HighD(bckGrndIdx) = 0;
            
            out_nii.img = HighD;

            [folder, name, ~] = fileparts(fn);
            save_untouch_nii(out_nii, fullfile(folder, ['IVIM-HighD_' name '.nii.gz']))

            %low
            LowD = reshape(LowD(1,:), [sx, sy, sz]);
            LowD(bckGrndIdx) = 0;
            
            out_nii.img = LowD;

            [folder, name, ~] = fileparts(fn);
            save_untouch_nii(out_nii, fullfile(folder, ['IVIM-LowD_' name '.nii.gz']))

            %f
            f = reshape(f, [sx, sy, sz]);
            f(bckGrndIdx) = 0;
            
            out_nii.img = f;

            [folder, name, ~] = fileparts(fn);
            save_untouch_nii(out_nii, fullfile(folder, ['IVIM-f_' name '.nii.gz']))


        end


        function status = ConvertSegmentations(app)
            %Finds all segmentations, converts them to the .json standard
            %that the app uses.

            status = 1;

            
            app.dlg.Value =  1;
        end

        function correctQ = correctBvals(bvals, st)
            Q1 = length(bvals) == st;
            Q2 = length(unique(bvals)) > 1;

            correctQ = Q1 && Q2;
        end

        function bvals = getCorrectBvals(st, fn)
            msg = ['Incorrect (number of) b-values found. Please enter the correct ',...
                    num2str(st), ' b-values, separated with spaces. ',...
                    fn];
            res = inputdlg(msg);

            bvals = str2num(res{1});
            if NewDatasetUtils.correctBvals(bvals, st)
                return
            else
                bvals = NewDatasetUtils.getCorrectBvals(st, fn);
            end
        end

        function bvalFn = makeBvalFile(st, fn)
            msg = ['Incorrect (number of) b-values found. Please enter the correct ',...
                    num2str(st), ' b-values, separated with spaces. ',...
                    fn];
            output = inputdlg(msg);

            bvalVec = str2num(output{1});
            if NewDatasetUtils.correctBvals(bvalVec, st)
                
                bvalFn = strrep(fn, '.nii.gz', '.bval');
                bvalFn = strrep(bvalFn, '.nii', '.bval');

                
                fid = fopen(bvalFn, 'wt' );
                fprintf(fid, '%s', output{:});
                fclose(fid);

            else
                NewDatasetUtils.makeBvalFile(st, fn);
            end
        end



    end
end
