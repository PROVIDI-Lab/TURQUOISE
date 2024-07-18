classdef Segmentation < handle
    methods(Static)        

        function FinalizeContour(app, segmentation)

            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            points = ROI.MaskToPointsNew(segmentation, view);

            %Pass the points to the app, and continue as with any other ROI
            app.points{app.axID} = points;
            Interaction.PromptName(app);

            %Cleanup
            app.ContourPickerApp.Close()

        end
        


        function segmentation = Seg2D(app, hitx, hity, sensitivity, method)
        %..    
            
            %TODO: fix x&y
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view};
            axis4D  = app.d4PerImage(imID);
            
            segmentation = zeros(size(app.data{imID}.img(:,:,:,axis4D)));

            if(view == 3)
                TheImg =                                                ...
                    app.data{imID}.img(...
                    :, :, slice, axis4D);
            elseif(view == 2)
                TheImg =                                                ...
                    squeeze(app.data{imID}.img(...
                    :, slice, :, axis4D));
            elseif(view == 1)
                TheImg = squeeze(app.data{imID}.img(...
                    slice, :, :, axis4D));
            end
            TheImg = single(TheImg);
            TheImg = TheImg / max(TheImg(:)) * 255;
            
            TheVal = TheImg(hity, hitx);

            switch method
                case 'ChanVese'
                    maskSlice = Segmentation.ChanVese2D(app, TheImg, ...
                        hitx, hity, true, sensitivity);
                case 'ChanVeseComplement'
                    maskSlice = Segmentation.ChanVese2D(app, TheImg, ...
                        hitx, hity, false, sensitivity);
                case 'LowerThreshold'
                    maskSlice = Segmentation.Thresh2D(TheImg, TheVal,...
                        hitx, hity, true, sensitivity);
                case 'HigherThreshold'
                    maskSlice = Segmentation.Thresh2D(TheImg, TheVal,...
                        hitx, hity, false, sensitivity);
                otherwise
                    errordlg("This method is not implemented")
                    segmentation = [];
                    return
            end       

            if(view == 3)
                segmentation(:, :, slice) = maskSlice;
            elseif(view == 2)
                segmentation(:, slice, :) = maskSlice;
            elseif(view == 1)
                segmentation(slice, :, :) = maskSlice;
            end
        end
        
        function segmentation = Thresh2D(TheImg, TheVal, hitx, hity, ...
                lowerQ, sensitivity)
            
            if lowerQ
                u = TheImg > TheVal-TheVal*sensitivity;
            else
                u = TheImg < TheVal+TheVal* sensitivity & TheImg > -1;
            end
            [LA,NA] = bwlabeln(u);
            for ijkid=1:NA
                lLA = LA == ijkid;
                if(lLA(hitx,hity) == 0)
                    u(lLA > 0) = 0;
                end
            end
            segmentation = u;
        end
        
        function segmentation = ChanVese2D(app, TheImg, hitx, hity, ...
                complementQ, sensitivity)
            if complementQ
                    TheImg = imcomplement(TheImg);
            end
            
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            u = zeros(size(TheImg));
            found = -1;
            if(~isempty(app.labels))
                if(view == 3)
                    L = app.labels(:,:,slice);
                elseif(view == 2)
                    L = squeeze(app.labels(:,slice,:));
                elseif(view == 1)
                    L = squeeze(app.labels(slice,:,:));
                end
                for l_id=min(L(:)):max(L(:))
                    V = L == l_id;
                    V = V(hitx-1:hitx+1,hity-1:hity+1);
                    if(sum(V(:)) > 0)
                        found = l_id;
                        break
                    end
                end
            end
            if(found == -1)
                u(hitx-1:hitx+1,hity-1:hity+1) = 1;
            else
                u = L==l_id;
            end
            segmentation = activecontour(TheImg,u,100,'Chan-Vese',      ...
                    'ContractionBias', sensitivity); 
        end
        
        
        function segmentation = Seg3D(app, hitx, hity, sensitivity, method)
        %...
        
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);   %todo -> use function from niftiutils
            slice   = app.slicePerImage{imID}{view};
            axis4D  = app.d4PerImage(imID);
            
            TheImg  = single(app.data{imID}.img(:,:,:, axis4D));
            TheImg  = TheImg / max(TheImg(:)) * 255;
            
            if(view == 3)
                TheVal = TheImg(hity,hitx,slice);
            elseif(view == 2)
                TheVal = TheImg(hity,slice,hitx);
            elseif(view == 1)
                TheVal = TheImg(slice,hity,hitx);
            end

            switch method
                case 'ChanVese'
                    segmentation = Segmentation.ChanVese3D(app, TheImg, ...
                        hitx, hity, true, sensitivity);
                case 'ChanVeseComplement'
                    segmentation = Segmentation.ChanVese3D(app, TheImg, ...
                        hitx, hity, false, sensitivity);
                case 'LowerThreshold'
                    segmentation = Segmentation.Thresh3D(app, TheImg, TheVal,...
                        hitx, hity, true, sensitivity);
                case 'HigherThreshold'
                    segmentation = Segmentation.Thresh3D(app, TheImg, TheVal,...
                        hitx, hity, false, sensitivity);
                otherwise
                    errordlg("This method is not implemented")
                    segmentation = [];
            end

        end
        
        function segmentation = Thresh3D(app, TheImg, TheVal, hitx, hity, ...
                lowerQ, sensitivity)
            
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view};
            
            if lowerQ
                u = TheImg > TheVal - TheVal*sensitivity;
            else
                u = TheImg < TheVal + TheVal*sensitivity & TheImg > -1; 
            end
            [LA,NA] = bwlabeln(u);

            if view == 3
                segmentation = LA == LA(hity, hitx, slice);
            elseif view == 2
                segmentation = LA == LA(hity, slice, hitx);
            elseif view == 1
                segmentation = LA == LA(slice, hity, hitx);
            end     
        end
        
        function segmentation = ChanVese(app, TheImg, hitx, hity, ...
                complementQ, sensitivity)
            if complementQ
                    TheImg = imcomplement(TheImg);
            end
            
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            u = zeros(size(TheImg));
            found = -1;
            if(~isempty(app.labels))
                if(view == 3)
                    L = app.labels(:,:,slice);
                elseif(view == 2)
                    L = squeeze(app.labels(:,slice,:));
                elseif(view == 1)
                    L = squeeze(app.labels(slice,:,:));
                end
                for l_id=min(L(:)):max(L(:))
                    V = L == l_id;
                    V = V(hity-1:hity+1,hitx-1:hitx+1);
                    if(sum(V(:)) > 0)
                        found = l_id;
                        break
                    end
                end
            end
            if(found == -1)
                if(view == 3)
                    u(hity-1:hity+1,hitx-1:hitx+1,                  ...
                        slice) = 1;
                elseif(view == 2)
                    u(hity-1:hity+1,slice,              ...
                        hitx-1:hitx+1) = 1;
                elseif(view == 1)
                    u(slice,hity-1:hity+1,              ...
                        hitx-1:hitx+1) = 1;
                end
            else
                u = app.labels == l_id;
            end

            segmentation = activecontour(TheImg,u,100,'Chan-Vese',  ...
                'ContractionBias', sensitivity);
        end        

    end
end