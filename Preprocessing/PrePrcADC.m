classdef PrePrcADC < handle
    methods (Static)

        function Start(app)
            d = uiprogressdlg(app.UIFigure, 'Title','Calculating ADCs');
            
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

                    PrePrcADC.ProcessFolder(app, folder.name, d, message)
                end
            else
                %single folder
                message = ['Folder 1 out of 1'];
                PrePrcADC.ProcessFolder(app, '', d, message)
            end

            close(d);
        end

        function ProcessFolder(app, folder, d, msg)
            files = dir(fullfile(app.filepath, folder,'*.mat'));
            for i = 1:length(files)

                m = sprintf('File %d of %d', i, length(files));
                d.Message = [msg ' ' m];

                file = files(i);

                %Load DWI array & bval array
                dta = load(fullfile(file.folder, file.name), 'DWI', 'b');
                dta.DWI = single(EDTI_Library.E_DTI_DWI_cell2mat(dta.DWI));

                MD = PrePrcADC.calcADC(dta);

                niftiwrite(MD, ...
                    fullfile(app.outpath, folder,...
                    strrep(file.name, '.mat', '_ADC.nii')))
            end
        end


        function MD = calcADC(dta)
    
            [sx,sy,sz,st] = size(dta.DWI);
            dta.DWI = permute(reshape(dta.DWI,sx*sy*sz,st),[2 1]);
        
            X = [ones(size(dta.b,1),1) -dta.b]; % fit including intercept
            
            DT = X\log(dta.DWI);
            DT = permute(DT,[2 1]);
            % S0 = reshape(DT(:,1),sx,sy,sz);
            DT = DT(:,2:end);
            DTexp = DT(:,[1 5 6 4 2 5 5 6 3]); % stacks 3x3 at the end of the vector
            DTcell = num2cell(DTexp,2);
            
            % equivalent to for loop over the first dimension
            [eigvec,eigval] = cellfun(@(x) eig(reshape(x,3,3)),DTcell,'UniformOutput', false); 
            eigval = abs(cell2mat(reshape(eigval,sx,sy,sz)));
            eigval = permute(eigval,[3 1 2]);
            eigval = permute(reshape(eigval,sz,3,sx,3,sy),[3 5 1 2 4]);
            MD = mean(cat(4,eigval(:,:,:,1,1),eigval(:,:,:,2,2),eigval(:,:,:,3,3)),4);
            MD = permute(MD, [2,1,3]);
        end

        
       

    end
end 