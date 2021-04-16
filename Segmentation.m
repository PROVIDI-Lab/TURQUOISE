classdef Segmentation < handle
    methods(Static)        

        function MouseMagicDraw(app,hit,hitx,hity)
        % This handles the magic draw, in 2D and 3D, for different
        % algorithms
        
            Cv      = app.current_view;
            if(hit.Button == 1)

                if(app.drawing.magic_3d == false)
                    segmentation = Segmentation.Seg2D(app, hitx, hity);
                else
                    segmentation = Segmentation.Seg3D(app, hitx, hity);
                end
                
                Objects.AddNewUserObj(app,...
                    "type", 1, ...
                    "data", segmentation,...
                    "points", [], ...
                    "name", Segmentation.GetName(app))
                
            elseif(hit.Button == 3)
                app.drawing.mode = 0;
                app.MagicdrawButton.BackgroundColor = [.96 .96 .96];
            end
        end
        
        function Seg2D(app, hitx, hity)
        %..    
            
            %TODO: fix x&y
            Cv      = app.current_view;
            imID    = app.imagePerAxis(Cv);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            if(view == 3)
                TheImg =                                                ...
                    app.data{imID}.img(...
                    :, :, slice, app.current_4d_idx);
            elseif(view == 2)
                TheImg =                                                ...
                    squeeze(app.data{imID}.img(...
                    :, slice, :, app.current_4d_idx));
            elseif(view == 1)
                TheImg = squeeze(app.data{imID}.img(...
                    slice, :, :, app.current_4d_idx));
            end
            TheImg = single(TheImg);
            TheImg = TheImg / max(TheImg(:)) * 255;
            
            

            if(app.drawing.magic_method < 3)
                TheVal = TheImg(hitx,hity);
                segmentation = Segmentation.Thresh2D(app, TheImg, TheVal,...
                    hitx, hity);
            elseif(app.drawing.magic_method == 3 ||...
                    app.drawing.magic_method == 4)
                segmentation = Segmentation.ChanVese2D(app, TheImg, ...
                    hitx, hity);
            end       
        end
        
        function segmentation = Thresh2D(app, TheImg, TheVal, hitx, hity)
            
            if(app.drawing.magic_method == 1)
                    u = TheImg >                                        ...
                        TheVal-TheVal*app.drawing.magic_sensitivity/10;
            elseif(app.drawing.magic_method == 2)
                u = TheImg < TheVal+TheVal*...
                    app.drawing.magic_sensitivity/10 &...
                    TheImg > -1;
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
        
        function segmentation = ChanVese2D(app, TheImg, hitx, hity)
            if(app.drawing.magic_method == 4)
                    TheImg = imcomplement(TheImg);
            end
            
            imID    = app.imagePerAxis(app.current_view);
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
                    'ContractionBias',                                  ...
                    app.drawing.magic_sensitivity / 10.0); 
        end
        
        
        function segmentation = Seg3D(app, hitx, hity)
        %...
        
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            TheImg  = single(app.data{imID}.img(:,:,:,app.current_4d_idx));
            TheImg  = TheImg / max(TheImg(:)) * 255;
            
            method = app.drawing.magic_method;
             if method == 1 || method == 2
                if(view == 3)
                    TheVal = TheImg(hity,hitx,slice);
                elseif(view == 2)
                    TheVal = TheImg(hity,slice,hitx);
                elseif(view == 1)
                    TheVal = TheImg(slice,hity,hitx);
                end
                
                segmentation = Segmentation.Thresh3D(app, TheVal, TheImg,...
                    hitx, hity);                
                
            elseif(app.drawing.magic_method == 3 ||...
                    app.drawing.magic_method == 4)
                segmentation = Segmentation.ChanVese(app, TheImg, ...
                    hitx, hity);
            end
        end
        
        function segmentation = Thresh3D(app, TheVal, TheImg, hitx, hity)
            
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            
            if app.drawing.magic_method == 1
                u = TheImg > ...
                            TheVal-TheVal*app.drawing.magic_sensitivity/10;
            else
                u = TheImg < TheVal + ...
                        TheVal*app.drawing.magic_sensitivity/10  ...
                        & TheImg > -1; 
            end
            [LA,NA] = bwlabeln(u);
            for ijkid=1:NA
                lLA = LA == ijkid;
                if(view == 3 &&                            ...
                        lLA(hity,hitx,slice) == 0)
                    u(lLA > 0) = 0;
                elseif(view == 2 &&                        ...
                        lLA(hity,slice,hitx) == 0)
                    u(lLA > 0) = 0;
                elseif(view == 1 &&                        ...
                        lLA(slice,hity,hitx) == 0)
                    u(lLA > 0) = 0;
                end
            end     
            segmentation = u;
        end
        
        function segmentation = ChanVese(app, TheImg, hitx, hity)
            if(app.drawing.magic_method == 4)
                    TheImg = imcomplement(TheImg);
            end
            
            imID    = app.imagePerAxis(app.current_view);
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
                'ContractionBias',                                  ...
                app.drawing.magic_sensitivity / 10.0);
        end
        
        function name = GetName(app)
            switch app.drawing.magic_method
                case 1
                    method = 'UpperThresh';
                case 2 
                    method = 'LowerThresh';
                case 3 
                    method = 'UpperChanVese';
                case 4
                    method = 'LowerChanVese';                
            end
            
            if app.drawing.magic_3d
                dim = '3D';
            else
                dim = '2D';
            end
            
            name = strcat('Auto-',method,'-',dim);
        end
        
        
        

    end
end