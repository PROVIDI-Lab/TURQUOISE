<img alt="workflow" src="https://github.com/user-attachments/assets/daf3639f-8def-46cc-b59b-b715c9564557" />

# TURQUOISE
TUmoR QUantification, prOcessIng, and SEgmentation of oncological multicenter MRI data

TURQUOISE is an open-source software platform for quantitative MRI analysis, designed to support clinical imaging research through an integrated workflow for data management, image processing, segmentation, and quantitative analysis.

The software provides a graphical user interface (GUI) tailored for cohort-based imaging studies and supports both manual and semi-automated segmentation workflows, as well as extensibility through a lightweight plugin framework.

The tool was developed to facilitate reproducible analysis of quantitative imaging biomarkers, particularly in multicenter MRI studies, where consistent processing pipelines are essential.

## Example workflow
A typical workflow in TURQUOISE consists of the following steps:

1. Dataset creation\
Raw DICOM data are imported and organized into a structured dataset. Diffusion-weighted imaging (DWI) series are automatically detected and used to generate derived quantitative maps such as ADC and IVIM parameters when suitable acquisitions are available.
2. Dataset selection and launch\
The launcher interface allows quick switching between datasets and studies. Different segmentation profiles can be used to separate segmentations from different raters or algorithms.
3. Segmentation\
TURQUOISE provides multiple tools for defining regions of interest:
- Manual polygon-based segmentation
- Semi-automated contour-based segmentation
- Circular ROI placement
- Interactive ROI editing and refinement
4. Dataset management\
Cohort-level tools allow efficient navigation through subjects, imaging sessions, scans, and segmentation profiles.
5. Quantitative analysis\
Quantitative imaging biomarkers can be computed and visualized within defined regions of interest, including histogram-based comparisons of diffusion metrics.

## Features
Key features of TURQUOISE include:

- GUI-based quantitative imaging workflow
- Cohort-level dataset management
- Manual and semi-automated segmentation tools
- Support for multicenter and longitudinal datasets
- Automatic generation of ADC and IVIM maps
- Built-in tools for ROI-based quantitative analysis
- Plugin framework for advanced analysis methods
- Multiple segmentation profiles for inter/intra-rater studies
- Offline operation for secure clinical research environments

## Creating a dataset

To initialize a dataset:

1. Start TURQUOISE
2. Select Create dataset
3. Choose a directory containing DICOM data
4. The dataset wizard will:
-scan all imaging series
-extract metadata
-detect diffusion scans
-generate derived maps (ADC / IVIM)

The dataset will then be available in the launcher.

The program assumes the following organisation for the input DICOM files:

```bash
├── Study_name
      └── PatientID
            └── SessionXX          
                  └── ScanName        (Optional)
                        ├── 001.dcm
                        ├── 002.dcm
                        └── ...
```

Example
```bash
├──Study_name
      └── PID0001
            └── Session01
                ├── 001.dcm
                └── ...
            └── Session02
                ├── 001.dcm
                └── ...
```

## Plugins
TURQUOISE includes a lightweight plugin system that allows new processing methods to be integrated into the software without modifying the core application.
Example plugins are included in the repository. The Wiki contains a Plugin Guide.

## Citation

If you use TURQUOISE in your research, please cite:
[TBD]

## Contact

Developed by the PROVIDI Lab
Image Sciences Institute
UMC Utrecht

### A note on orientation & coordinates
There are many different (confusing) ways to navigate MR images. TURQUOISE uses four of them. The main three are world coordinates (xyz), patient directions (LR, AP, SI), and image coordinates (ijk). As Matlab uses a different origin when interacting with an image (top left) we add a fourth system (row, column or rc). 

The program has many built-in functions to switch between coordinate systems.
-    ijk2xyz converts from image coordinates to world coordinates
-    xyz2ijk converts from world coordinates to image coordinates
-    rc2ijk converts from a position on the screen to image coordinates
-    rc2xyz converts from a position on the screen to world coordinates (via the image coordinates)
-    ijk2rc converts from image coordinates to a position on the screen

