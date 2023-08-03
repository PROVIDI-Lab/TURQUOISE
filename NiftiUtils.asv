% Nifti utilities for RMS Studio

classdef NiftiUtils < handle
    
    methods (Static)

        function nii = PermuteFlip(nii)
            %Permutes and flips the image oriantation to match Matlab's
            %preferred way of showing images (y,x,z)

            img = nii.img;
            order = 1:length(size(img));
            order(1) = 2;
            order(2) = 1;
            img = permute(img, order);
            img = flip(img, 1);
            nii.img = img;

%             %hdr
%             srow_x = nii.hdr.hist.srow_x;
%             srow_y = nii.hdr.hist.srow_y;
%             nii.hdr.hist.srow_x = -srow_y;
% %             nii.hdr.hist.srow_x = srow_y;
%             nii.hdr.hist.srow_y = srow_x;
% 
%             dimx    = nii.hdr.dime.dim(2);
%             dimy    = nii.hdr.dime.dim(3);
%             nii.hdr.dime.dim(2) = dimy;
%             nii.hdr.dime.dim(3) = dimx;

        end

        function nii = FlipPermute(nii)
            %Permutes and flips the image oriantation back to the normal
            %way. Used when saving images.

            img = nii.img;
            img = flip(img, 1);
            img = permute(img, [2,1,3]);
            nii.img = img;

%             %hdr
%             srow_x = nii.hdr.hist.srow_x;
%             srow_y = nii.hdr.hist.srow_y;
%             nii.hdr.hist.srow_x = srow_y;
%             nii.hdr.hist.srow_y = -srow_x;
% %             nii.hdr.hist.srow_y = srow_x;
% 
%             dimx    = nii.hdr.dime.dim(2);
%             dimy    = nii.hdr.dime.dim(3);
%             nii.hdr.dime.dim(2) = dimy;
%             nii.hdr.dime.dim(3) = dimx;

        end


        
        function tm = getTransformationMatrix(hdr)
            srow_x = hdr.hist.srow_x;
            srow_y = hdr.hist.srow_y;
            srow_z = hdr.hist.srow_z;

            tm = [srow_x; srow_y; srow_z; [0,0,0,1]];
        end        

        function ref = GetRefHalfway(hdr)
            %Returns the real world coordinate reference to halfway the
            %image -- Assumes all images are axial (TODO - fix!!)

            srow_x = hdr.hist.srow_x;
            srow_y = hdr.hist.srow_y;
            srow_z = hdr.hist.srow_z;
            tm = [srow_x; srow_y; srow_z];

            %Reference r_middle is calculated as:
            % ref = r_0 + M * dim / 2
            % where r_0 is the offset, M the rest of the transformation
            % matrix, and dim a vector containing the dimensions of the
            % image.

            M = tm(:,1:3);
            r0  = tm(:,4);
            dim = [hdr.dime.dim(2);...
                   hdr.dime.dim(3);...
                   hdr.dime.dim(4);];

            ref = r0 + M*dim / 2;
        end

        function [xref, yref] = GetSliceBoundary(app, axID, view, slice)

            imID        = app.imagePerAxis(axID);
            tm          = app.transMatPerImage{imID};
            sz          = size(app.data{imID}.img);

            if view == 1
                minRef = [slice, 0, 0, 1];
                maxRef = [slice, sz(2), sz(3), 1];
            elseif view == 2
                minRef = [0, slice, 0, 1];
                maxRef = [sz(1), slice, sz(3), 1];
            else
                minRef = [0, 0, slice, 1];
                maxRef = [sz(1), sz(2), slice, 1];
            end

            minRef = tm * minRef';
            maxRef = tm * maxRef';

            minRef(view) = [];
            maxRef(view) = [];

            xref = [minRef(1), maxRef(1)];
            yref = [minRef(2), maxRef(2)];

        end

        function [x,y,z] = GetMeshgridFromHeader(hdr)
            %Calculates a grid for the image in real world coordinates. To
            %be used in interpolation

            srow_x = hdr.hist.srow_x;
            srow_y = hdr.hist.srow_y;
            srow_z = hdr.hist.srow_z;
            tm = [srow_x; srow_y; srow_z];

            dim = [hdr.dime.dim(2);...
                   hdr.dime.dim(3);...
                   hdr.dime.dim(4);];

            %Create basic grid
            [x, y, z]   = ndgrid(...
                            1 : 1 : dim(1),...
                            1 : 1 : dim(2),...
                            1 : 1 : dim(3));
            grid        = [reshape(x, 1, []);...
                           reshape(y, 1, []);...
                           reshape(z, 1, []);
                           ones(1,numel(x))];

            %Transform to get positions of voxels
            grid    = tm * grid;

            %Reshape to usable arrays.
            x       = reshape(grid(1,:), dim');
            y       = reshape(grid(2,:), dim');
            z       = reshape(grid(3,:), dim');

        end

        function or = FindOrientation(tm)
            %Finds the orientation of the nifti image based on the header
            %info. Returns the results as:
            %   [positive i direction, negative i direction, 
            %    positive j direction, negative j direction, 
            %    [cor/sag/ax]]
            
            [~,iOrr] = max(abs(tm(:,1)));
            iSign = sign(tm(iOrr,1));

            [~,jOrr] = max(abs(tm(:,2)));
            jSign = sign(tm(jOrr,2));

            orr_vec = {'LR', 'AP', 'SI'};

            iOrrString = orr_vec{iOrr};
            if iSign == -1
                iOrrString = reverse(iOrrString);
            end

            jOrrString = orr_vec{jOrr};
            if jSign == -1
                jOrrString = reverse(jOrrString);
            end

            if iOrr == 1 && jOrr == 2
                orrCode = 'a'; %axial
            elseif iOrr == 1 && jOrr == 3
                orrCode = 'c'; %coronal
            elseif iOrr == 2 && jOrr == 3
                orrCode =  's'; %sagittal
            else
                orrCode = 'a'; %If orientation is unclear, try axial
            end

            or = [iOrrString, jOrrString, orrCode];            

        end

        function or = FindOrientationWithAxis(tm, viewingAxis)
            %Finds the orientation of the nifti image based on the header
            %info. Returns the results as:
            %   [positive i direction, negative i direction, 
            %    positive j direction, negative j direction, 
            %    [cor/sag/ax]]
            
            [~,iOrr] = max(abs(tm(:,1)));
            iSign = sign(tm(iOrr,1));

            [~,jOrr] = max(abs(tm(:,2)));
            jSign = sign(tm(jOrr,2));

            [~,kOrr] = max(abs(tm(:,3)));
            kSign = sign(tm(kOrr,3));

            orr_vec = {'LR', 'AP', 'SI'};

            iOrrString = orr_vec{iOrr};
            if iSign == -1
                iOrrString = reverse(iOrrString);
            end

            jOrrString = orr_vec{jOrr};
            if jSign == -1
                jOrrString = reverse(jOrrString);
            end

            kOrrString = orr_vec{kOrr};
            if kSign == -1
                kOrrString = reverse(kOrrString);
            end

            if iOrr == 1 && jOrr == 2
                orrCode = 'a'; %axial
            elseif iOrr == 1 && jOrr == 3
                orrCode = 'c'; %coronal
            elseif iOrr == 2 && jOrr == 3
                orrCode =  's'; %sagittal
            else
                orrCode = 'a'; %If orientation is unclear, try axial
            end

            imageOr     = strfind('csa', orrCode); 
            % or_Mat      = [3,1,2; 2,3,1; 1,2,3];
            % view        = or_Mat(imageOr, viewingAxis);

            %find which directions should be displayed
            if imageOr == 1 %Coronal image
                if viewingAxis == 1 %coronal projection -> RLIS
                    strings     = [iOrrString, jOrrString];
                elseif viewingAxis == 2 %sagittal projection -> APIS
                    strings     = [reverse(kOrrString), jOrrString];
                else    %axial projection -> LRAP
                    strings     = [iOrrString, reverse(kOrrString)];
                end

            elseif imageOr == 2 %Sagittal image
                if viewingAxis == 1 %coronal projection -> RLIS
                    strings     = [reverse(kOrrString), jOrrString];
                elseif viewingAxis == 2 %sagittal projection -> APIS
                    strings     = [reverse(iOrrString), jOrrString];
                else    %axial projection -> LRAP
                    strings     = [reverse(kOrrString), reverse(iOrrString)];
                end
            else
                if viewingAxis == 1 %coronal projection -> RLIS
                    strings     = [iOrrString, kOrrString];
                elseif viewingAxis == 2 %sagittal projection -> APIS
                    strings     = [jOrrString, kOrrString];
                else    %axial projection -> LRAP
                    strings     = [iOrrString, jOrrString];
                end
            end
            

            
            % strings(2*viewingAxis-1:2*viewingAxis) = [];

            or = [strings, orrCode];            
        
        end

        function viewDim = FindViewingDimension(app, imID, varargin)
            %Returns the dimension needed for a certain view, given the
            %image orientation and a certain projection.
            %e.g. an axial image with a sagittal projection will have a
            %viewDim of 1 (the first dimension of the 3D image shows the
            %sagittal projection)
            % You can find this from the viewing axis, and the image 
            % orientation as follows:
            %                           viewing axis
            %                   cor         sag         ax
            %           cor     k           i           j
            %im Orr     sag     i           k           j
            %           ax      j           i           k


            %if viewaxis is specified in varargin, use that. if not, use
            %viewPerImage
            if nargin == 2
                viewAxis    = app.viewPerImage(imID);
            else
                viewAxis    = varargin{1};
            end

            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            or_Mat      = [3,1,2; 1,3,2; 2,1,3];
            viewDim     = or_Mat(imageOr, viewAxis);
        end

        function proj = findProjectionFromViewDim(app, imID, objViewDim)
            %Takes the imID and the viewdim of the object to find out what
            %projection was used to draw the object.

            %e.g. if the image orientation is sagittal, and the viewdim is
            %3, then the object was drawn in a sagittal projection.

            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            projMat     = [2,3,1; 1,3,2; 2,1,3];
            proj        = projMat(imageOr, objViewDim);
        end

        function res = FindInPlaneResolution(app, imID)
            %Gives the x,y resolution of the image that should be
            %displayed, given the image orientation and projection

            %Ex. a coronal image with total resolution 256, 256, 100 is
            %projected sagitally. The in-plane resolution will be 100x256
            %(x,y).

            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            res         = size(app.data{imID}.img);
            viewingAxis = app.viewPerImage(imID);

            if imageOr == 1 %Coronal image
                if viewingAxis == 1 %coronal projection
                    res          = [res(1), res(2)];
                elseif viewingAxis == 2 %sagittal projection 
                    res          = [res(3), res(2)];
                else    %axial projection
                    res          = [res(1), res(3)];
                end

            elseif imageOr == 2 %Sagittal image
                if viewingAxis == 1 %coronal projection
                    res          = [res(3), res(2)];
                elseif viewingAxis == 2 %sagittal projection 
                    res          = [res(1), res(2)];
                else    %axial projection
                    res          = [res(3), res(1)];
                end

            else    %Axial image
                if viewingAxis == 1 %coronal projection
                    res          = [res(1), res(3)];
                elseif viewingAxis == 2 %sagittal projection
                    res          = [res(2), res(3)];
                else    %axial projection
                    res          = [res(1), res(2)];
                end
            end


        end

        function [xq,yq,zq] = GetDisplayGrid(app, axID)
            %In order to find the display grid, we take the current
            %reference r_m and create a grid in the plane of the selected
            %image orientation.
            %The grid size (in world coordinates) is based on the zoom
            %level. The grid spacing is based on the size of the window.

            
            %find viewing dimension, as described in findViewingDimension
            imID        = app.imagePerAxis(axID);
            viewAxis    = app.viewPerImage(imID); 
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            or_Mat      = [3,2,1; 2,3,1; 1,2,3];
            view        = or_Mat(imageOr, viewAxis);    %final projection
            slice       = app.slicePerImage{imID}{viewAxis};

            %Make grid spacing based on image dimensions
            hdr     = app.data{imID}.hdr;
            dim     = [hdr.dime.dim(2);...
                        hdr.dime.dim(3);...
                        hdr.dime.dim(4)];
            slice = slice - dim(view)/2;

            dim(view)   = [];
            dimx = dim(1);
            dimy = dim(2);
%             dimx        = max(dim);
%             dimy        = max(dim);

            if view == 1 
                [xq, yq, zq] = meshgrid(1, ...
                                        1:1:dimx,...
                                        1:1:dimy);                
            elseif view == 2 
                [xq, yq, zq] = meshgrid(1:1:dimx,...   
                                        1,...
                                        1:1:dimy);                
            elseif view == 3 
                [xq, yq, zq] = meshgrid(1:1:dimx,...
                                        1:1:dimy, ...
                                        1);
            end

            gridDim     = size(xq);
            grid        = [reshape(xq, 1, []);...
                           reshape(yq, 1, []);...
                           reshape(zq, 1, []);
                           ones(1,numel(xq))];

            %Turn on for visualisation
%             gridO       = tm * grid;
%             xqO       = reshape(gridO(1,:), gridDim);
%             yqO       = reshape(gridO(2,:), gridDim);
%             zqO       = reshape(gridO(3,:), gridDim);
            
            %Create transformation matrix used to go from image plane to
            %scanner coordinates.
            %start with the transformation matrix of the current image,
            %then scale by the difference between the scan resolution and 
            %the display resolution
            %Next, adapt the transformation matrix to user settings
            %(zooming & scrolling)

            params  = app.viewingParams;
            tm      = NiftiUtils.AdaptTransMat(...
                            tm, dim(1), dim(2), slice, view, params);

            %Transform grid to get sampling locations
            grid    = tm * grid;

%             turn on for visualisation
%             xq       = reshape(grid(1,:), gridDim);
%             yq       = reshape(grid(2,:), gridDim);
%             zq       = reshape(grid(3,:), gridDim);
%             [x,y,z] = NiftiUtils.GetMeshgridFromHeader(...
% app.data{imID}.hdr);
%             scatter3(x(1:501:end), y(1:501:end),z(1:501:end), 10)
%             hold on
%             scatter3(xq(1:21:end), yq(1:21:end), zq(1:21:end), 5)
% %             scatter3(xqO(1:20:end), yqO(1:20:end), zqO(1:20:end),...
% 5, 'red')
%             xlabel('x')
%             ylabel('y')
%             zlabel('z')
%             hold off

            %Lastly, use the inverse of the original image 
            % transformation matrix to get ijk coordinate sampling 
            % positions.
            grid        = app.transMatPerImage{imID} \ grid;

            %Reshape to usable arrays.
            xq       = reshape(grid(1,:), gridDim);
            yq       = reshape(grid(2,:), gridDim);
            zq       = reshape(grid(3,:), gridDim);
                        

        end

        function tm = AdaptTransMat(tm, resx, resy, slice, ...
                view, params)
        %Makes the following changes to the transformation matrix:
        %   Applies scaling and translation as defined by
        %user input. Scaling = zooming, translation is scrolling.
        %   Non-viewing axes are centered around the reference.

        %Input:
        %   tm      - transformation matrix before any changes are made
        %   resGrid - size of the (square) sampling grid
        %   resx    - image dimension in the x axis
        %   resy    - image dimension in the y axis
        %   slice   - offset in viewing axis (for scrolling)
        %   view    - index to go from ijk to desired projection
        %   params  - other offsets and scale factors to be used

            %Zoom in image plane
            zoomFactor  = params(4);
            zoomTm      = tm(1:3,1:3);
            zoomTm      = zoomTm * zoomFactor;
            tm(1:3,1:3) = zoomTm;

            %translation
            delta = params(1:3);
            tm(view,4) = delta(view);   %Center view halfway the scan

            %overlay centres & scroll
            %If ijk coordinates to center are provided, use those. If not,
            %center halfway the image (including view-axis slice).

            imAxes              = [1,2,3];
            imAxes(view)        = [];
            halfPoint           = ones(4,1);
            halfPoint(imAxes)   = [resx/2, resy/2];
            halfPoint(view)     = slice;    %scroll through view axis

            halfPointDist       = tm * halfPoint;
            deltaCenter         = params(1:3)' - halfPointDist(1:3);
            tm(1:3,4)           = tm(1:3,4) + deltaCenter;
        end

        function [xq,yq,zq] = Get3DGrid(hdr, tm, offset)
            %In order to find the 3D grid, we take the current
            %reference r_m and create a grid 
            
            %Make grid spacing based on image dimensions
            dim     = [hdr.dime.dim(2);...
                        hdr.dime.dim(3);...
                        hdr.dime.dim(4)];

            imOrr   = NiftiUtils.FindOrientation(tm);
            
            if strcmp(imOrr(5), 's')
                [yq, zq, xq] = meshgrid(1:1:dim(1),...
                                        1:1:dim(2), ...
                                        1:1:dim(3));             
            elseif strcmp(imOrr(5), 'c')
                [xq, zq, yq] = meshgrid(1:1:dim(1),...
                                        1:1:dim(2), ...
                                        1:1:dim(3));            
            elseif strcmp(imOrr(5), 'a')
                [xq, yq, zq] = meshgrid(1:1:dim(1),...
                                        1:1:dim(2), ...
                                        1:1:dim(3));
            end
            
            gridDim     = size(xq);
            grid        = [reshape(xq, 1, []);...
                           reshape(yq, 1, []);...
                           reshape(zq, 1, []);
                           ones(1,numel(xq))];

            %Turn on for visualisation
%             gridO       = tm * grid;
%             xqO       = reshape(gridO(1,:), gridDim);
%             yqO       = reshape(gridO(2,:), gridDim);
%             zqO       = reshape(gridO(3,:), gridDim);
            
            %Translate the transformation matrix
            newTM   = tm;

            halfPoint           = [dim(1)/2, dim(2)/2, dim(3)/2, 1];
            halfPointDist       = tm * halfPoint';
            deltaCenter         = offset' - halfPointDist(1:3);
            newTM(1:3,4)        = tm(1:3,4) + deltaCenter;

            %Transform grid to get sampling locations
            grid    = newTM * grid;

%             turn on for visualisation
%             xq       = reshape(grid(1,:), gridDim);
%             yq       = reshape(grid(2,:), gridDim);
%             zq       = reshape(grid(3,:), gridDim);
%             [x,y,z] = NiftiUtils.GetMeshgridFromHeader(...
% app.data{imID}.hdr);
%             scatter3(x(1:501:end), y(1:501:end),z(1:501:end), 10)
%             hold on
%             scatter3(xq(1:21:end), yq(1:21:end), zq(1:21:end), 5)
% %             scatter3(xqO(1:20:end), yqO(1:20:end), zqO(1:20:end),...
% 5, 'red')
%             xlabel('x')
%             ylabel('y')
%             zlabel('z')
%             hold off

            %Lastly, use the inverse of the original image 
            % transformation matrix to get ijk coordinate sampling 
            % positions.
            grid        = tm \ grid;

            %Reshape to usable arrays.
            xq       = reshape(grid(1,:), gridDim);
            yq       = reshape(grid(2,:), gridDim);
            zq       = reshape(grid(3,:), gridDim);
        end


        function img = MoveToRWC(app, nii)
            %Interpolates image based on real world reference from the
            %study

            d4 = size(nii.img, 4);
            tm = NiftiUtils.getTransformationMatrix(nii.hdr);
            img = zeros(size(nii.img));

            for i = 1:d4
                imData = nii.img(:,:,:,i);
                [xq, yq, zq] = NiftiUtils.Get3DGrid(nii.hdr, tm, ...
                    app.viewingParams(1:3));

                newImData = interp3(imData, xq, yq, zq, 'linear', 0);
                img(:,:,:,i) = newImData;
            end

        end

        function showGrid(app, axID, xq, yq, zq)

            imID        = app.imagePerAxis(axID);
            d4          = app.d4PerImage(imID);
            imData      = app.data{imID}.img(:,:,:,d4);

            [x,y,z] = NiftiUtils.GetMeshgridFromHeader(app.data{imID}.hdr);
            grid        = [reshape(x, 1, []);...
                           reshape(y, 1, []);...
                           reshape(z, 1, []);
                           ones(1,numel(x))];

            %Transform to get positions of voxels
            tm          = app.transMatPerImage{imID};
            gridk    = tm \ grid;

            %Reshape to usable arrays.
            dim = size(imData);
            xk       = reshape(gridk(1,:), dim);
            yk       = reshape(gridk(2,:), dim);
            zk       = reshape(gridk(3,:), dim);
% 
            %plot
            scatter3(xq(1:20:end), yq(1:20:end), zq(1:20:end), 5)
            xlabel('i')
            ylabel('j')
            zlabel('k')
            hold on
            [sx,sy,sz] = size(imData);
            scatter3([0,sx,0,0,sx,sx,0,sx], [0,0,sy,0,sy,0,sy,sy],...
                [0,0,0,sz,0,sz,sz,sz])
            hold on 
            scatter3(xk(1:200:end), yk(1:200:end),zk(1:200:end), 10)
            hold off

        end

        function xyz = ijk2xyz(tm, ijk)
            %Converts image coordinates to world coordinates with the help
            %of the image transformation matrix.

            ijk = ijk - 1;  %offset because matlab arrays start at 1

            if length(ijk) == 3
                ijk(end+1) = 1;
            end

            if size(ijk, 2) > size(ijk, 1)
                ijk = ijk';
            end

            xyz = tm * ijk;
            xyz = xyz(1:3);
        end

        function ijk = xyz2ijk(~, tm, xyz, axID)
            %Converts world coordinates to image coordinates with the help
            %of the image transformation matrix.

            if length(xyz) == 3
                xyz(end+1) = 1;
            end

            if size(xyz, 2) > size(xyz, 1)
                xyz = xyz';
            end

            ijk = tm \ xyz;
            ijk = ijk(1:3);
            ijk = ijk + 1; %offset because matlab arrays start at 1

        end

        function ijk = rc2ijk (app, row, column, varargin)
            %Find the image coordinates (ijk) from the current location.
            %Input:
            %row - x position in plane
            %column - y position in plane
            %varargin - might contain axID.

            if nargin == 4
                axID    = varargin{1};
            else
                axID    = app.axID;
            end

            imID            = app.imagePerAxis(axID);
            viewingAxis     = app.viewPerImage(imID); 
            slice           = app.slicePerImage{imID}{viewingAxis};
            slice           = repmat(slice, size(row));

            %Put row, column, and slice in the right order to get to image
            %coordinates ijk. 

            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 

            if imageOr == 1 %Coronal image
                if viewingAxis == 1 %coronal projection
                    ijk = [row, column, slice];
                elseif viewingAxis == 2 %sagittal projection 
                    ijk = [slice, column, row];
                else    %axial projection
                    sz  = size(app.data{imID}.img, 3);
                    k   = sz - column;
                    k   = max(k, 1);   
                    k   = min(k, sz);
                    ijk = [row, slice, k];
                end

            elseif imageOr == 2 %Sagittal image
                if viewingAxis == 1 %coronal projection
                    sz  = size(app.data{imID}.img, 3);
                    ijk = [slice, column, sz - row];
                elseif viewingAxis == 2 %sagittal projection 
                    ijk = [row, column, slice];
                else    %axial projection
                    szk  = size(app.data{imID}.img, 3);
                    szi  = size(app.data{imID}.img, 1);
                    ijk = [szi - column, slice, szk - row];
                end 

            else    %Axial image
                if viewingAxis == 1 %coronal projection
                    ijk = [row, slice, column];
                elseif viewingAxis == 2 %sagittal projection
                    sz  = size(app.data{imID}.img, 2);
                    ijk = [slice, sz - row + 1, column];
                else    %axial projection
                    ijk = [row, column, slice];
                end
            end

            %bound to prevent any accidental rounding errors
            ijk(ijk == 0) = 1;

        end


        function xyz = rc2xyz (app, row, column, varargin)
            %We go from image coordinates to world coordinates.

            
            if nargin == 4
                axID = varargin{1};            
            else
                axID = app.axID;
            end

            %First, get the image coordinates from the cursor location
            ijk = NiftiUtils.rc2ijk(app, row, column, axID);

            %Next, multiply with the transformation matrix to get world
            %coordinates
            imID        = app.imagePerAxis(axID);
            tm          = app.transMatPerImage{imID};
            xyz         = NiftiUtils.ijk2xyz(tm, ijk);  

        end
       
        function [row, column] = ijk2rc(app, axID, ijk, varargin)
        %Takes the image coordinates ijk and returns display
        %coordinates row and column. 

            imID        = app.imagePerAxis(axID);
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            viewAxis    = app.viewPerImage(imID);
            imageOr     = strfind('csa', or(5)); 
            or_Mat      = [3,1,2; 1,3,2; 2,1,3];
            view        = or_Mat(imageOr, viewAxis);

            %If a slice is provided in varargin, first select only those 
            %coordinates with a matching slice.
            if nargin == 4
                slice = varargin{1};
                idx             = ijk(:, view) ~= slice;
                ijk(idx,:)      = [];
            end

            %Start with the non-axis image coordinates
            ijk(:, view)    = [];
            row               = ijk(:,1);
            column               = ijk(:,2);

            %Next, Get image dimensions, needed to flip certain axes
            sz          = size(app.data{imID}.img);
            sz(view)    = [];

            %Under some circumstances, x and y need to be swapped
            if viewAxis == 2 && imageOr == 1 || ... %corimage, sag proj.
               viewAxis == 1 && imageOr == 2 || ... % sag im, cor proj.
               viewAxis == 3 && imageOr == 2        % sag im, ax proj.
                c = row;
                row = column;
                column = c;
                sz = flip(sz);
            end

            %flip y because image coordinates are 0,0 in the bottom
            %left and matlab coordinates are 0,0 in top left.
            if imageOr == 1 && viewAxis == 3 || ... %cor im, axial proj.
               imageOr == 2 && viewAxis == 3        % sag im, ax proj.
                %don't flip with these projections
            else
                column   = sz(2) - column;
            end
            
            %Under some circumstances, x position needs to inverted as
            %well
            if viewAxis == 2 && imageOr == 3 || ... % ax im, Sagittal proj
               viewAxis == 1 && imageOr == 2 || ... % sag im, cor proj.
               viewAxis == 3 && imageOr == 2        % sag im, ax proj.
                
                row = sz(1) - row;
            end    
        end

    end
    
end
