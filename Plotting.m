classdef Plotting < handle
    methods (Static)

        function Labels3DView(app)
        % Show a 3D plot of the labels    

        return %todo change for UO system
        
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
    end
end














