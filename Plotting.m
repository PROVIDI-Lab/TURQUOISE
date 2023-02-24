classdef Plotting < handle
    methods (Static)
        
        
        function ShowHistogram(app, obj)
            %Displays the histogram of the ROI with the given userobject

            d4          = app.d4PerImage(obj.imageIdx);
            img         = app.data{obj.imageIdx}.img(:,:,:,d4);
            
            tmp = Interaction.overlayMask(img, obj.data);
            if mean(tmp(:)) > 500
                tmp = tmp / 1000;
            elseif mean(tmp(:)) < 0.5
                tmp = tmp * 1000;
            end

            %apply mask tot ADC
            figure
            h = histogram(tmp);
            xline(mean(tmp))
            str = sprintf('Mean = %f', mean(tmp));
            text(mean(tmp), max(h.Values)/4*3, str)
            yticks([])
        end

        function Labels3DView(app)
        % Show a 3D plot of the labels    
            f=figure;
            ax = axes(f);
            hold(ax,'on');
            axis(ax,'vis3d');
            axis(ax,'off');
            cameratoolbar(f);
            
            Cv  = app.current_view;
            for N=1:max(app.segmentation{Cv}.img(:))
               L = app.segmentation{Cv}.img == N;
               L = smooth3(L,'gaussian',5);
               h(N) = patch(ax,isosurface(L,0.3),                       ...
                   'FaceColor',                                         ...
                   [1 1 1],                                             ...
                   'EdgeColor',                                         ...
                   'none');
%                isonormals(L,h);
%                h.BackFaceLighting = 'reverselit';
            end
            lighting(ax,'gouraud');
            camlight(ax,'headlight'); 
            for N=1:length(h)
               h(N).FaceColor =                                         ...
                   [randi(100)/100 randi(100)/100 randi(100)/100];
               h(N).FaceLighting = 'gouraud';
               h(N).EdgeLighting = 'gouraud';
            end
        end
        
        function LabelsStatsPlot(app)
            % Show statistics of each label
            
            %TODO: update for UOs
            return
            
            Cv      = app.current_view;
            axis4D  = app.d4PerImage(app.imIdx);
            im      = app.data{app.imIdx}.img(:,:,:, axis4D);
            min_val = inf;
            max_val = -inf;
            f       = figure;
            
            %First find the range that the histogram needs to be shown
            %with:
            %iterate over all labels in image
            for N=1:max(app.segmentation{Cv}.img(:))
                
               %Get list of all labeled values
               L = app.segmentation{Cv}.img == N;
               S = im(L(:) > 0);
               if(isempty(S))
                   continue
               end
               
               %Find histogram min_val and max_val
               if(max(S(:)) > max_val)
                   max_val = max(S(:));
               end
               if(min(S(:)) < min_val)
                   min_val = min(S(:));
               end
            end
            
            %iterate over all labels in image
            for N=1:max(app.segmentation{Cv}.img(:))
                
               %Get list of all labeled values
               L = app.segmentation{Cv}.img == N;
               S = im(L(:) > 0);
               if(isempty(S))
                   continue
               end
               
               %Make histogram
               nbins = 30;
               step = (max_val-min_val)/nbins;
               range = min_val:step:max_val;
               h = hist(S(:),range);
               if(length(h) < 2)
                   continue
               end
               
               %Get name of segmentation
               Name        = app.seg_names{N};
               
               %Plot histogram
               ax=subplot(max(app.segmentation{Cv}.img(:)),1,N);
               bar(ax,range,h);
               hold on;
               Nvoxels = length(S);
               title([Name ' - NVox ' num2str(Nvoxels)]);
               [current_max_val,max_ind] = max(h);
               max_plot = plot([range(max_ind) range(max_ind)],         ...
                                [0 current_max_val],'--r','LineWidth',2);
               mean_val = mean(S(:));
               mean_plot = plot([mean_val mean_val],                    ...
                                [0 current_max_val],'--g','LineWidth',2);
               prctiles = prctile(S,[5 95]);
               legend([max_plot mean_plot],                             ...
                   {['Modus: ' sprintf('%.2f',range(max_ind))],       ...
                   ['Mean: ' sprintf('%.2f',mean_val)]},            ...
                   'Location',                                          ...
                   'best');
            end
        end     
    end
end














