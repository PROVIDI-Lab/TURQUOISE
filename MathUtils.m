% A. De Luca - UMC Utrecht - alberto@isi.uu.nl
% Math utilities for TURQUOISE

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
                    [X,Y,Z]     = meshgrid(1:1:size(in_vol,2),  ...
                                           1:1:size(in_vol,1),  ...
                                           1:1:size(in_vol,3));
                    
                    
                    [Xq, Yq, Zq]= meshgrid(1:1/ratio(1):size(in_vol,2), ...
                                           1:1/ratio(2):size(in_vol,1), ...
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
            fp = app.sessionPath;
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
        
        function [rMin, rMax] = GetNewRange(rDelta, r, r0, r1)
            %Calculates the min and max values of a range with width rDelta
            %such that r is in the same position relative to the new
            %min and max as it was to r0 and r1.             
            
            
            ratio   = (r1-r) / (r1-r0);
            rMin    = r - (rDelta * (1 - ratio));
            rMax    = (rDelta * ratio) + r;
            if rMax <= rMin
               rMax = rMin + 1;
            end
           
        end
        
        
        function dist = CalcDistancePointLine(p0, p1, p2)
        %Calculates the closest distance between a point and a line 
        %(as defined by two points).
        %See: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
            
            x0  = p0(1); y0  = p0(2); x1  = p1(1); y1  = p1(2);
            x2  = p2(1); y2  = p2(2);
            
            dist    = abs( (x2-x1)*(y1-y0) - (x1-x0)*(y2-y1)) / ...
                sqrt((x2-x1)^2 + (y2-y1)^2);
            
        end 


        function slice = ApplyProjection(app, imQ, maskQ, ID, d4, ...
                imOrr, proj, sliceNum)

            %Takes a 3D array and returns a slice from a certain projection
            %at a certain index.
            %
            %input:
            %app,   RMSstudio pointer
            %imQ,   True if loading an image, false if loading an ROI
            %maskQ, True if loading the roi mask, false if loading outline
            %ID,    imID or ROI ID
            %d4,    4th axis if loading an image
            %imOrr,  orientation of the array. 1=cor, 2= sag, 3 = ax
            %proj,   projection 1=cor, 2= sag, 3 = ax

            if imQ
                arr = app.data{ID}.img(:,:,:,d4);
            else
                if maskQ
                    arr = app.userObjects{ID}.data(:,:,:,d4);
                else
                    arr = app.userObjects{ID}.outlineData(:,:,:,d4);
                end
            end

            slice = MathUtils.ApplyProjectionToArray( ...
                arr, imOrr, proj, sliceNum);

        end

        function slice = ApplyProjectionToArray(arr, imOrr, proj, sliceNum)

            %Takes a 3D array and returns a slice from a certain projection
            %at a certain index.
            %
            %input:
            %app,   RMSstudio pointer
            %mask,  the mask to get a projection from
            %imOrr,  orientation of the array. 1=cor, 2= sag, 3 = ax
            %proj,   projection 1=cor, 2= sag, 3 = ax
            %slice,  slice position

            %
            %The projection is gained as follows:
            %imOrr  projection  axis    other steps
            %cor    cor         3       -
            %cor    sag         2       -
            %cor    ax          1       invert axis, rotate90, flip y.
            %
            %sag    cor         2       flip y.
            %sag    sag         3       -
            %sag    ax          1       invert axis, flip y.
            %
            %ax     cor         1       invert axis, rotate 90
            %ax     sag         2       rotate 90
            %ax     ax          3       -

            %Here, the axTable is inverted with regards to the matrix when
            %it's used in NiftiUtils. At least, elements '1' and '2' are
            %switched. This is because of matlab shenanigans I think??!
            axTable     = [3,2,1; 2,3,1; 1,2,3];
            invTable    = [0,0,1; 0,0,1; 1,0,0];
            rotTable    = [0,0,1; 0,0,0; 1,1,0];
            flipTable   = [0,0,1; 0,0,0; 0,0,0];
            flipXTable  = [0,0,0; 1,0,1; 0,0,0];

            ax  = axTable(imOrr, proj);
            inv = invTable(imOrr, proj);
            rot = rotTable(imOrr, proj);
            flp = flipTable(imOrr, proj);
            flpx= flipXTable(imOrr, proj);

            if inv  %invert axis
                switch ax
                    case 1
                        slice = arr( ...
                            max(end-sliceNum + 1, 1), :, :);
                    case 2
                        slice = arr( ...
                            :, max(end-sliceNum + 1, 1), :);
                    case 3
                        slice = arr( ...
                            :, :, max(end-sliceNum + 1, 1));
                end
            else
                switch ax
                    case 1
                        slice = arr(sliceNum, :, :);
                    case 2
                        slice = arr(:, sliceNum, :);
                    case 3
                        slice = arr(:, :, sliceNum);
                end
            end

            slice = squeeze(slice);

            if rot
                slice = rot90(slice);
            end

            if flp
                slice = flip(slice);
            end

            if flpx
                slice = flip(slice,2);
            end

        end


        function sortedPoints = SortPointsByDistance(points)
        %Takes n-by-2 point array and sorts them such that each point is
        %adjacent to the points closest to it.

            %remove duplicate points
            points = unique(points, 'rows');

            %Calculate distance matrix
            distanceMatrix = squareform(pdist(points));
            distanceMatrix(distanceMatrix == 0) = Inf;

            %Initialize indexes & output
            pIdx = zeros(length(points), 1);
            pIdx(1) = 1;
            sortedPoints = [points(1,:)];

            %Loop over each point. for each point, find the point with the
            %smallest distance, given by the distanceMatrix. That point is
            %added to sortedPoint.
            %All values for the current point in the distanceMatrix are set
            %to inf. Next, repeat for the new point.
            for i = 1 : length(points)-1
                
                idx = pIdx(i);

                [d, newIdx]     = min(distanceMatrix(idx,:));
                if d > 10
                    break
                end
                sortedPoints    = [sortedPoints; points(newIdx, :)];
                pIdx(i+1)     = newIdx;
                distanceMatrix(:,idx) = Inf;
            end
        end
    end
end