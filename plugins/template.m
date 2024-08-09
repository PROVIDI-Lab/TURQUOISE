classdef template   %rename to your choice of plugin name
    properties
        app     % pointer to the TURQUOISE app.
    end

    methods (Access = public)
        function obj = template(app)    %rename 
            obj.app = app;  %initialize the app
            
            %You can add more code here, but this will all be run on app
            %startup, so no images etc are loaded.
        end

        function Excecute() %runs when the plugin is selected from the menu
            %Your code here
        end
    end

    methods (Access = private)
        %Add any sub-functions here.

    end
       
end