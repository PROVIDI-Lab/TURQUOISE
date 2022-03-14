classdef Analysis < handle
    methods (Static)

        function ApplyMasks(app)

            %TODO: add/subtract buttons & list

            fig = uifigure('Name', 'Copy segmentations', ...
                'Position',[500 500 600 400]);

            btn = uibutton(fig,...
                'Position',[250 50 100 22],...
                'Text','Apply Masks');
            
            slctSegLbl = uilabel(fig,...
                'Position', [470, 300, 150, 22],...
                'Text', 'Select segmentations');
            slctSeg = uilistbox(fig,...
                'Position', [425, 100, 150, 200]);
            slctSeg.Multiselect = 'on';
            slctAllSeg= uicheckbox(fig,...
                'Position', [425, -50, 150, 200],...
                'Text', 'Select all',...
                'ValueChangedFcn', @SelectAllSeg);

            slctImageLbl = uilabel(fig,...
                'Position', [40, 300, 150, 22],...
                'Text', 'Select Image');
            slctImage = uilistbox(fig,...
                'Position', [25, 100, 150, 200],...
                'ValueChangedFcn',@SwitchImage);

            %Button callback
            btn.ButtonPushedFcn = {@Analysis.ApplyMask, app};

            %Fill listboxes
            segList = {};
            for i=1:length(app.studyNames)
                segList{i} = IOUtils.FindAllSegmentationsForImage(app, i);
            end
            slctSeg.Items = segList{app.imIdx};

            Images = app.studyNames;
            slctImage.Items = Images;

            function SwitchImage(src, ~)
                [~, index] = ismember(...
                    src.Parent.Children(1).Value, ...
                    src.Parent.Children(1).Items);
                src.Parent.Children(4).Items = segList{index};

                SelectAllSeg(src, 1)

            end

            function SelectAllSeg(src, ~)
                if src.Value
                    src.Parent.Children(4).Value = ...
                        src.Parent.Children(4).Items;
                else
                    src.Parent.Children(4).Value = {};
                end
            end
        end

        function ApplyMask(src, ~, app)
            
            name = src.Parent.Children(1).Value;
            segs = src.Parent.Children(4).Value;
            
            adc_fn = fullfile(...
                app.current_folder,...
                [name, '.rmsstudio_reslice.nii']);

            segPath = fullfile(...
                app.current_folder,...
                name, app.user_profile);

            adc = load_nii(adc_fn);
%             adc     = IOUtils.PermuteFlip(adc);
            img = adc.img;
            total_mask = permute(zeros(size(img)),[2,1,3]);


            for i = 1:length(segs)
                
                seg = segs{i};
                fn = fullfile(...
                    segPath,...
                    [seg, '-segmentation.json']);

                mask = Analysis.points2mask(fn, adc_fn);
                mask = flip(flip(mask, 1),2); %figure out why...
                total_mask = total_mask + mask;

            end

            adc_list = Analysis.overlayMask(img, total_mask);
            adc_list(isnan(adc_list)) = [];
            out_fn = fullfile(...
                        segPath,...
                        'ADC_vals.txt');
            fileID = fopen(out_fn, 'w');
            fprintf(fileID, adc_list);
            fclose(fileID);

            
        end

        function mask = points2mask(pointfn, imgfn)
            fid  = fopen(pointfn, 'r');
            txt  = fread(fid,inf);
            txt  = char(txt');
            fclose(fid);
            data = jsondecode(txt);
            points = data.points;
            points  = round(points);
            points(end+1,:) = points(1,:);
        
            img     = load_nii(imgfn).img;
            mask    = false(size(img(:,:,:)));
            
            if size(points,1) == 2
                %Find position of circle
                x0                  = points(1,1);
                y0                  = points(1,2);
                x1                  = points(2,1);
                y1                  = points(2,2);
                rad                 = pdist([x0,y0; x1,y1],'euclidean');
        
                %Sample enough points
                nPoints = round(2 * rad * pi); 
                angles  = linspace(0, 2*pi, nPoints);
                x       = round(rad * cos(angles) + x0);
                y       = round(rad * sin(angles) + y0);
                z       = ones(1, nPoints) * points(1,3);
                points  = [x;y;z]';
            end
            
            
            
            %Add all pixels in between the vertices to the mask
            for x=2:size(points,1)
                mask(...
                    points(x-1,1),...
                    points(x-1,2),...
                    points(x-1,3))  = 1;
                mask(...
                    points(x,1),...
                    points(x,2),...
                    points(x,3))    = 1;
        
                %Construct vector between point x and x-1
                d = points(x,:)-points(x-1,:);
                d = d/norm(d,2);
                if(any(isnan(d)))
                    continue
                end
        
                %Add all points between the most recently drawn points
                catcher = 1;
                while (catcher < 500)
                    p = round(points(x-1,:)+d*catcher);
                    mask(p(1),p(2),p(3)) = 1;
                    if(all(p-points(x,:) == 0))
                        break
                    end
                    catcher = catcher + 1;
                end
                if(catcher == 500)
                    disp('Catcher!');
                end
        
            end
        
            %finalise segmentation, fill all holes
            for iz  = 1:size(mask, 3)
                mask(:,:,iz) = imfill(mask(:,:,iz), 'holes');
            end
            
            %Permute X&Y to match nii image
            
            mindim      = min(size(mask,[1,2]));
            im          = zeros(mindim, mindim, size(mask,3));
            im(:,:,:)   = mask(1:mindim, 1:mindim, :);
            mask(1:mindim, 1:mindim, :)     = im;
            
        end

        function values = overlayMask(im, mask)

            %Overlays mask over image, takes into account different shapes
            minx = min(size(im,1), size(mask,1));
            miny = min(size(im,2), size(mask,2));
        
            newMask = mask(1:minx, 1:miny, :);
            newIm   = im(1:minx, 1:miny, :);
        
            values = newIm(newMask == 1);            
        end





        
    end
end            