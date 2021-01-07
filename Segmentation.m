classdef Segmentation < handle
    methods(Static)        

        function MouseMagicDraw(app,hit,hitx,hity)
        % This handles the magic draw, in 2D and 3D, for different
        % algorithms
            if(hit.Button == 1)
                if(~isfield(app.segmentation,'hdr'))
                    app.segmentation.hdr = app.data.hdr;
                    app.segmentation.img = zeros(size(app.data.img(:,:,:,1)));
                end

                GUI.DisableControlsStatus(app);
                pause(0.01);
                drawnow
                %                     h = waitbar(0,'Please wait');

                if(app.drawing.magic_3d == false)
                    Segmentation.Seg2D(app, hitx, hity)
                else
                    Segmentation.Seg3D(app, hitx, hity)
                end
                %                     close(h);
                pause(0.05);
                drawnow
                %                     app.UIFigure.Visible = 'off';
                %                     app.UIFigure.Visible = 'on';
                GUI.RevertControlsStatus(app);
            elseif(hit.Button == 3)
                app.drawing.magic = false;
                app.MagicdrawButton.BackgroundColor = [.96 .96 .96];
            end
        end
        
        function Seg2D(app, hitx, hity)
            
            
            %TODO: fix x&y
                %Change to work with current ROI functions
            
            if(app.view_axis == 3)
                TheImg =                                                ...
                    app.data.img(:,:,app.current_slice,app.current_4d_idx);
            elseif(app.view_axis == 2)
                TheImg =                                                ...
                    squeeze(app.data.img(                               ...
                    :,app.current_slice,:,app.current_4d_idx));
            elseif(app.view_axis == 1)
                TheImg = squeeze(app.data.img(                          ...
                    app.current_slice,:,:,app.current_4d_idx));
            end
            TheImg = single(TheImg);
            TheImg = TheImg / max(TheImg(:)) * 255;

            if(app.drawing.magic_method < 3)
                TheVal = TheImg(hitx,hity);
                if(app.drawing.magic_method == 1)
                    u = TheImg >                                        ...
                        TheVal-TheVal*app.drawing.magic_sensitivity/10;
                elseif(app.drawing.magic_method == 2)
                    u = TheImg <                                        ...
                        TheVal+TheVal*app.drawing.magic_sensitivity/10 &...
                        TheImg > -1;
                end
                [LA,NA] = bwlabeln(u);
                for ijkid=1:NA
                    lLA = LA == ijkid;
                    if(lLA(hitx,hity) == 0)
                        u(lLA > 0) = 0;
                    end
                end
            elseif(app.drawing.magic_method == 3 ||                     ...
                    app.drawing.magic_method == 4)
                if(app.drawing.magic_method == 4)
                    TheImg = imcomplement(TheImg);
                end
                u = zeros(size(TheImg));
                found = -1;
                if(~isempty(app.labels))
                    if(app.view_axis == 3)
                        L = app.labels(:,:,app.current_slice);
                    elseif(app.view_axis == 2)
                        L = squeeze(app.labels(:,app.current_slice,:));
                    elseif(app.view_axis == 1)
                        L = squeeze(app.labels(app.current_slice,:,:));
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
                u = activecontour(TheImg,u,100,'Chan-Vese',             ...
                    'ContractionBias',                                  ...
                    app.drawing.magic_sensitivity / 10.0);
            end

            if(app.view_axis == 3)
                L = app.segmentation.img(:,:,app.current_slice);
                L(u > 0) = 1;
                app.segmentation.img(:,:,app.current_slice) = L;
            elseif(app.view_axis == 2)
                L = squeeze(app.segmentation.img(:,app.current_slice,:));
                L(u > 0) = 1;
                app.segmentation.img(:,app.current_slice,:) = L;
            elseif(app.view_axis == 1)
                L = squeeze(app.segmentation.img(app.current_slice,:,:));
                L(u > 0) = 1;
                app.segmentation.img(app.current_slice,:,:) = L;
            end

            ROI.UpdateSegmentationProperties(app)          
        end
        
        
        function Seg3D(app, hitx, hity)
            
           TheImg = single(app.data.img(:,:,:,app.current_4d_idx));
            TheImg = TheImg / max(TheImg(:)) * 255;
            if(app.drawing.magic_method < 3)
                if(app.view_axis == 3)
                    TheVal = TheImg(hity,hitx,app.current_slice);
                elseif(app.view_axis == 2)
                    TheVal = TheImg(hity,app.current_slice,hitx);
                elseif(app.view_axis == 1)
                    TheVal = TheImg(app.current_slice,hity,hitx);
                end
                if(app.drawing.magic_method == 1)
                    u = TheImg >                                        ...
                        TheVal-TheVal*app.drawing.magic_sensitivity/10;
                elseif(app.drawing.magic_method == 2)
                    u = TheImg <                                        ...
                        TheVal+TheVal*app.drawing.magic_sensitivity/10  ...
                        & TheImg > -1;
                end
                [LA,NA] = bwlabeln(u);
                for ijkid=1:NA
                    lLA = LA == ijkid;
                    if(app.view_axis == 3 &&                            ...
                            lLA(hity,hitx,app.current_slice) == 0)
                        u(lLA > 0) = 0;
                    elseif(app.view_axis == 2 &&                        ...
                            lLA(hity,app.current_slice,hitx) == 0)
                        u(lLA > 0) = 0;
                    elseif(app.view_axis == 1 &&                        ...
                            lLA(app.current_slice,hity,hitx) == 0)
                        u(lLA > 0) = 0;
                    end
                end
            elseif(app.drawing.magic_method == 3 ||                     ...
                    app.drawing.magic_method == 4)
                if(app.drawing.magic_method == 4)
                    TheImg = imcomplement(TheImg);
                end
                u = zeros(size(TheImg));
                found = -1;
                if(~isempty(app.labels))
                    if(app.view_axis == 3)
                        L = app.labels(:,:,app.current_slice);
                    elseif(app.view_axis == 2)
                        L = squeeze(app.labels(:,app.current_slice,:));
                    elseif(app.view_axis == 1)
                        L = squeeze(app.labels(app.current_slice,:,:));
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
                    if(app.view_axis == 3)
                        u(hity-1:hity+1,hitx-1:hitx+1,                  ...
                            app.current_slice) = 1;
                    elseif(app.view_axis == 2)
                        u(hity-1:hity+1,app.current_slice,              ...
                            hitx-1:hitx+1) = 1;
                    elseif(app.view_axis == 1)
                        u(app.current_slice,hity-1:hity+1,              ...
                            hitx-1:hitx+1) = 1;
                    end
                else
                    u = app.labels == l_id;
                end

                u = activecontour(TheImg,u,100,'Chan-Vese',             ...
                    'ContractionBias',                                  ...
                    app.drawing.magic_sensitivity / 10.0);
            end
            if(any(size(app.segmentation.img) ~=                        ...
                    size(app.data.img(:,:,:,1))))
                app.segmentation.img = u > 0;
            else
                app.segmentation.img = app.segmentation.img | u > 0;
            end
            ROI.UpdateSegmentationProperties(app)     
            
        end
        
        
        
    end
end