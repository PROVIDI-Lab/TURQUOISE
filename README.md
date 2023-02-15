# RMSStudio
A repository for the RMS analysis tool: RMSStudio


Creating a dataset. The program assumes the following organisation for the input Dicom files:
- Top-level folder
-     Patients
-         Session(s) <-- subfolder required even if only one session is present
-           Scans (optional)
-              Dicom files

E.g.
-Folder
-     PID0001
-         Session01
-             001.dcm
-             002.dcm


