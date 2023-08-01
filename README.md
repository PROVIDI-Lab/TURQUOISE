# RMSStudio
A repository for the RMS analysis tool: RMSStudio


Creating a dataset. The program assumes the following organisation for the input Dicom files:
-   Top-level folder
-     Patients
-         Session(s) <-- subfolder required even if only one session is present
-           Scans (optional)
-              Dicom files

E.g.
-   Folder
-     PID0001
-         Session01
-             001.dcm
-             002.dcm


# A note on orientation & coordinates
There are many different (confusing) ways to navigate MR images. RMSStudio uses four of them. The main three are world coordinates (xyz), patient directions (LR, AP, SI), and image coordinates (ijk). As Matlab uses a different origin when interacting with an image (top left) we add a fourth system (row, column or rc). 

The program has many built-in functions to switch between coordinate systems.
-    ijk2xyz converts from image coordinates to world coordinates
-    xyz2ijk converts from world coordinates to image coordinates
-    rc2ijk converts from a position on the screen to image coordinates
-    rc2xyz converts from a position on the screen to world coordinates (via the image coordinates)
-    ijk2rc converts from image coordinates to a position on the screen

