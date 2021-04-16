classdef Align < handle
    methods (Static)
        
        function t = GetTransformMatrix(nii)
            %Constructs the transformation matrix for going from i,j,k
            %pixel values to x,y,z coordinates. Assumes sform_code > 1.
            %See: https://nifti.nimh.nih.gov/nifti-1/documentation/
            %nifti1fields/nifti1fields_pages/srow.html/
            
            t = zeros(4,4);
            t(1,:) = nii.hdr.hist.srow_x;
            t(2,:) = nii.hdr.hist.srow_y;
            t(3,:) = nii.hdr.hist.srow_z;
            t(4,4) = 1;
            
            
        end
        
        function coords = GetWorldCoordinates(arr, t)
           %Returns the world coordinates x,y,z obtained by applying the 
           %transformation matrix t to the coordinates of the array i,j,k.
           
           [sx, sy, sz] = size(arr);
           [x, y, z]    = meshgrid(1:sx, 1:sy, 1:sz);
           xp           = x(:);
           yp           = y(:);
           zp           = z(:);
           coords       = [xp, yp, zp, ones(size(xp))];
           coords       = coords * t;         
        end
        
        function coords = GetMaskWorldCoordinates(mask, t)
            [xp,yp,zp] = ind2sub(size(mask), find(mask));
            coords       = [xp, yp, zp, ones(size(xp))];
            coords       = coords * t;         
        end
        
        function image = SampleAtCoords(coords, arr)
           %Interpolates a fixed nii image at the coordinates of the moving
           %one. 
           
           %First, reshape the coordinates to the image dimensions
%            Xq   = reshape(coords(:,1),size(fixed.img));
%            Yq   = reshape(coords(:,2),size(fixed.img));
%            Zq   = reshape(coords(:,3),size(fixed.img));
            Xq = coords(:,1);
            Yq = coords(:,2);
            Zq = coords(:,3);
           
            image        = interp3(arr, Xq, Yq, Zq);                      
        end
        
        function moving = AlignNiis(fixed, moving)
            %Interpolates the moving nii to the coordinates of the fixed
            %one. 
            
            tFixed  = Align.GetTransformMatrix(fixed);
            tMoving = Align.GetTransformMatrix(moving);
            
            fixedCoords     = Align.GetWorldCoordinates(...
                                fixed.img, tFixed);
            
            %Use inverse of transformation matrix to go from XYZ to IJK
            qCoords         = fixedCoords / tMoving;
            alignedImage    = Align.SampleAtCoords(...
                                qCoords,  moving.img);
            alignedImage(isnan(alignedImage))   = 0;
            moving.img      = alignedImage;            
        end
        
        function newMask    = AlignMask(fixed, moving, mask)
            %Interpolates the moving mask to fit on top of the fixed image.
            %Optimised to only sample mask coordinates.
            tFixed  = Align.GetTransformMatrix(fixed);
            tMoving = Align.GetTransformMatrix(moving);
            
            fixedCoords     = Align.GetMaskWorldCoordinates(...
                                mask, tFixed);
            
            %Use inverse of transformation matrix to go from XYZ to IJK
            qCoords         = fixedCoords / tMoving;
            sampled         = Align.SampleAtCoords(...
                                qCoords, mask);
            newMask         = zeros(size(fixed.img));
            idx             = sub2ind(...
                size(newMask), qCoords(:,1), qCoords(:,2), qCoords(:,3));
            newMask(idx)    = sampled;
            newMask(isnan(newMask)) = 0;
        end
    end
end