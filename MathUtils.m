% A. De Luca - UMC Utrecht - alberto@isi.uu.nl
% Math utilities for RMS Studio
% v1: 14/03/2019
classdef MathUtils < handle
    
    methods (Static)
        
        % Center of mass of a cloud of points
        function [Mx,My,MaxX,MaxY] = WeightedCenterOfROI(SL)
            T = sum(SL(:));
            AVX = (1:size(SL,1))'.*sum(SL,2);
            AVY = (1:size(SL,2)).*sum(SL,1);
            MaxX = find(AVX,1,'last');
            MaxY = find(AVY,1,'last');
            Mx = sum(AVX)/T;
            My = sum(AVY)/T;
        end
        
        % Isotropic resampling & interpolating
        function [out_vol, ratio] = ResampleVolume(in_vol,in_vs,out_vs)
            if(any(in_vs ~= out_vs))
                ratio       = in_vs./out_vs;
                out_vol     = [];
                for idx_4d  = 1:size(in_vol,4)
                    C = in_vol(:,:,:,idx_4d);
                    
                    %Create grids for interpolating
                    [X,Y,Z]     = meshgrid(1:1:size(in_vol,1),  ...
                                           1:1:size(in_vol,2),  ...
                                           1:1:size(in_vol,3));
                    
                    
                    [Xq, Yq, Zq]= meshgrid(1:1/ratio(1):size(in_vol,1), ...
                                           1:1/ratio(2):size(in_vol,2), ...
                                           1:1/ratio(3):size(in_vol,3));
                    
                    %Interpolate
                    V           = interp3(X, Y, Z, C, Xq, Yq, Zq);
                    out_vol     = cat(4,out_vol, V);
                end
            else
                out_vol = in_vol;
            end
        end
        
        % Handle image registration via Elastix
        % Todo: Strip auto all graphics from here
        function PerformElastixRegistration(app,target)
            
            %Find the path of dcm2nii
            if exist('elastix','dir')
                elastix = what('elastix');

                %if multiple versions exist, take the first one
                if ~all(size(elastix) == 1)
                    elastix = elastix(1);
                end

                elastix_b   = strcat(elastix.path, '\elastix_64');
                transformix = strcat(elastix.path, '\trasnformix_64');
                
%         if(exist(elastix_b,'file') < 1)
%             warning(["Matlab can't find elastix_64.exe on its path. "... 
%             "Make sure it's installed and added to the path.\n"...
%             "This can be done with 'addpath()'."]);
%         end
%         if(exist(transformix,'file') < 1)
%          warning(["Matlab can't find transformix_64.exe on its path. "... 
%                  "Make sure it's installed and added to the path.\n"...
%                  "This can be done with 'addpath()'."]);
%         end
            else
                warning(["Matlab can't find elastix on its path. "... 
                "Make sure it's installed and added to the path.\n"...
                "This can be done with 'addpath()'."])
                return
            end
            
            %todo, change parameter_files location lookup
            parameter_files =...
                {strcat('C:\Users\user\Dropbox\MRIToolkit\',...
                'ImageRegistrations\elastix_parameters\parrig_NN.txt')};
            fp = app.current_folder;
            fn1 = app.AvailableimagesListBox.Value(1:end-4);
            fn2 = target(1:end-4);
            if(strcmp(fn1,fn2) > 0)
                return
            end
            GraphicsAndInteraction.DisableControlsStatus(app);
            pause(0.01);
            drawnow
            %             h = waitbar(0,'Please wait');
            try
                if(exist(fullfile(fp,[fn1 '_2_' fn2],...
                        'TransformParameters.0.txt'),'file') < 1)
                    % Still to be registered, do it now
                    % PREPARE BOTH IMAGES
                    mkdir(fullfile(fp,[fn1 '_2_' fn2]));
                    
                    if(exist(fullfile(fp,...
                            [fn1 '.rmsstudio_reslice.nii']),'file') < 1)
                        hdr = load_untouch_header_only(...
                            fullfile(fp,[fn1 '.nii']));
                        reslice_nii(...
                            fullfile(fp,[fn1 '.nii']),...
                            fullfile(fp,[fn1 '.rmsstudio_reslice.nii']),...
                            hdr.dime.pixdim(2:4));
                    end
                    if(exist(...
                            fullfile(fp,...
                            [fn2 '.rmsstudio_reslice.nii']),'file') < 1)
                        hdr = load_untouch_header_only(...
                            fullfile(fp,[fn2 '.nii']));
                        reslice_nii(fullfile(...
                            fp,[fn2 '.nii']),...
                            fullfile(fp,[fn2 '.rmsstudio_reslice.nii']),...
                            hdr.dime.pixdim(2:4));
                    end
                    
                    moving = fullfile(fp,[fn1 '.rmsstudio_reslice.nii']);
                    fixed = fullfile(fp,[fn2 '.rmsstudio_reslice.nii']);
                    
                    hdr1 = load_untouch_header_only(...
                        fullfile(fp,[fn1 '.rmsstudio_reslice.nii']));
                    hdr2 = load_untouch_header_only(...
                        fullfile(fp,[fn2 '.rmsstudio_reslice.nii']));
                    if(hdr1.dime.dim(1) > 3)
                        f1 = load_untouch_nii(...
                            fullfile(fp,[fn1 '.rmsstudio_reslice.nii']));
                        f1.img = f1.img(:,:,:,1);
                        f1.hdr.dime.dim(1) = 3;
                        f1.hdr.dime.dim(5) = 1;
                        save_untouch_nii(...
                            f1,fullfile(fp,[fn1 '_2_' fn2],'f1.nii'));
                        fn14d = 1;
                    else
                        fn14d = 0;
                    end
                    if(hdr2.dime.dim(1) > 3)
                        f2 = load_untouch_nii(...
                            fullfile(fp,[fn2 '.rmsstudio_reslice.nii']));
                        f2.img = f2.img(:,:,:,1);
                        f2.hdr.dime.dim(1) = 3;
                        f2.hdr.dime.dim(5) = 1;
                        save_untouch_nii(...
                            f2,fullfile(fp,[fn1 '_2_' fn2],'f2.nii'));
                        fn24d = 1;
                    else
                        fn24d = 0;
                    end
                    
                    if(fn14d == 1)
                        moving = fullfile(fp,[fn1 '_2_' fn2],'f1.nii');
                    end
                    if(fn24d == 1)
                        fixed = fullfile(fp,[fn1 '_2_' fn2],'f2.nii');
                    end
                    
                    outdir = fullfile(fp,[fn1 '_2_' fn2]);
                    if(ispc < 1)
%                   elastix_location = strrep(elastix_location,' ','\ ');
%                        fixed = strrep(fixed,' ','\ '); 
%                        moving = strrep(moving,' ','\ '); 
%                        outdir = strrep(outdir,' ','\ '); 
                       system(['mkdir ' outdir]);
                    end
                    cmd = [elastix ' -out "' outdir '"' ...
                        ' -f "' fixed '"' ...
                        ' -m "' moving '"'];
                    for p_files = 1:length(parameter_files)
                        cmd = [cmd ' -p ' parameter_files{p_files}];
                    end

                    system(cmd);
                end
            catch err
                delete(fullfile(fp,[fn1 '_2_' fn2],'*'));
                rmdir(fullfile(fp,[fn1 '_2_' fn2]));
                %                 close(h);
                uialert(uifigure,err.message,'');
                                app.UIFigure.Visible = 'on';
                GraphicsAndInteraction.RevertControlsStatus(app);
            end
            
            delete(fullfile(fp,[fn1 '_2_' fn2],'*.nii'));
            if(exist(fullfile(fp,[fn1 '.rmsstudio.nii']),'file') > 0)
                for ol=10:-1:-1
                    if(exist(fullfile(fp,[fn1 '_2_' fn2],...
                        ['TransformParameters.' num2str(ol) '.txt']),...
                        'file') > 0)
                        break
                    end
                end
                if(ol > -1)
                    transf_p = fullfile(fp,[fn1 '_2_' fn2],...
                        ['TransformParameters.' num2str(ol) '.txt']);
                    cmd = [transformix ' -in "' fullfile(...
                        fp,[fn1 '.rmsstudio.nii']) '"' ...
                        ' -out "' fullfile(...
                        fp,[fn1 '_2_' fn2]) '" -tp "' transf_p '"'];
                    system(cmd);
                    result_file = dir(...
                        fullfile(fp,[fn1 '_2_' fn2],'*.nii'));
                    copyfile(fullfile(...
                        fp,[fn1 '_2_' fn2],result_file.name),...
                        fullfile(fp,[fn2 '.rmsstudio.nii']));
                else
                    delete(fullfile(fp,[fn1 '_2_' fn2],'*'));
                    rmdir(fullfile(fp,[fn1 '_2_' fn2]));
                end
            end
            
            for vol_id=1:length(app.AvailableimagesListBox.Items)
                if(strcmp([fn2 '.nii'],...
                        app.AvailableimagesListBox.Items{vol_id}) > 0)
                    break
                end
            end
            app.data_list{vol_id} = {};
            
            %             close(h);
            GraphicsAndInteraction.RevertControlsStatus(app);
                        app.UIFigure.Visible = 'off';
                        app.UIFigure.Visible = 'on';
            
        end
        
    end
    
end