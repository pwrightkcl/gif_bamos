# GIF

GIF stands for Geodesic Information Flows. Here are the original articles describing the method:

Cardoso MJ, Wolz R, Modat M, Fox NC, Rueckert D, Ourselin S. **Geodesic information flows.** *Med Image Comput Comput Assist 
Interv.* 2012;15(Pt 2):262-70. doi: [10.1007/978-3-642-33418-4_33](https://doi.org/10.1007/978-3-642-33418-4_33).

Cardoso MJ, Modat M, Wolz R, Melbourne A, Cash D, Rueckert D, Ourselin S. **Geodesic Information Flows: Spatially-Variant 
Graphs and Their Application to Segmentation and Fusion.** *IEEE Trans Med Imaging.* 2015 Sep;34(9):1976-88. 
doi: [10.1109/TMI.2015.2418298](https://doi.org/10.1109/TMI.2015.2418298).

## GIF outputs

The outputs from GIF are as follows:

| File suffix                     | Description                                |
|---------------------------------|--------------------------------------------|
| gw_affine.txt                   | affine to group template                   |
| NeuroMorph_BiasCorrected.nii.gz | bias corrected T1w image                   |
| NeuroMorph_Parcellation.nii.gz  | discrete segmentation                      |
| NeuroMorph_prior.nii.gz         | 9 volume probabilistic segmentation priors |
| NeuroMorph_Segmentation.nii.gz  | 9 volume probabilistic segmentation        |
| TIV.nii.gz                      | binary total intracranial volume mask      |
| NeuroMorph.xml                  | volumes for segmented regions              |

The 9 volume tissue classes in probabilistic segmentation is as follows:

1. Non-Brain Outer Tissue
2. Cerebral Spinal Fluid
3. Grey Matter
4. White Matter
5. Deep Grey Matter
6. Brain Stem and Pons
7. Non-brain low
8. Non-brain med
9. Non-brain high

The discrete segmentation uses 163 labels numbered between 0 and 208. These are partially based on the 
Neuromorphometrics labels with some customisation. The labels can be found in the dseg.tsv file.

The XML files gives volumes for the large tissue classes and smaller Neuromorphometrics regions. These are given as 
probabilistic and categorical. The probabilistic volumes are probably better for deep GM regions where the boundary may 
be gradual or ill-defined, whereas the categorical volume is better for cortex, where there is usually a clear boundary. 
To put it another way, probabilistic is more accurate whereas categorical is more precise.

## Installing GIF

### Compiled binary

The compiled binary is available at `/nfs/project/AMIGO/Tools/seg_GIF`.

### Compile form source

The source code for GIF is available at `/nfs/project/AMIGO/GIF`.

There is also a GIF repo here: [https://github.com/KCL-BMEIS/gif](https://github.com/KCL-BMEIS/gif).

You should be able to compile GIF with the following commands:

```bash 
mkdir /path/to/gif/build
cd /path/to/gif/build
cmake /path/to/gif/source/code
make
make install
```

## GIF database

GIF works by comparing the input image to a library of images with manually segmented structures. You need to specify 
the path to this database when running GIF.

There are two databases in the AMIGO space:

* /nfs/project/AMIGO/Tools/GIF/GIF_db
  * (5.9 GB)
* /nfs/project/AMIGO/GIF/database_GIF
  * (2.4 GB)

The larger GIF database (GIF_db, 160 images) contains data covered by a restricted ethics, but we have a signed data usage 
agreement for its use at KCL. The smaller database (database_GIF, 102 images) contains images from shareable, open 
source datasets.

## GIF usage

```text
  GIF (OpenMP x1):
  Usage -> /nfs/project/AMIGO/Tools/seg_GIF <mandatory> <options>


  * * * * * * * * * * * Mandatory * * * * * * * * * * * * * * * * * * * * * * * * *

    -in <filename>	| Input target image filename
    -db <XML>   	| Path to database <XML> file

  * * * * * * * * * * * General Options * * * * * * * * * * * * * * * * * * * * * *

    -mask <filename>	| Mask over the input image
    -out <path> 	| Output folder [./]
    -cpp <cpp_path>	| Read/store the cpps in <cpp_path>, rather than in memory 
    -geo 		| Save Geo to output folder
    -dis 		| Save distances to <cpp_path> if -cpp option is set 
    -upd 		| Update label given the previous db result.
    -dbt <fname> <tar>	| Sets a database (<fname>) specific target (<tar>) [in]
    -v <int>    	| Verbose level (0 = off, 1 = on, 2 = debug) [0]
    -omp <int>    	| Number of openmp threads [default=1, max=1]

  * * * * * * * * * * * Fusion Options * * * * * * * * * * * * * * * * * * * * * * *

    -lssd_ker <float>	| SSD kernel stdev in voxels (mm if negative) [-2.5]
    -ldef_ker <float>	| DEF kernel stdev in voxels (mm if negative) [-2.5]
    -lncc_ker <float>	| NCC kernel stdev in voxels (mm if negative) [-2.5]
    -t1dti_ker <float>	| T1DTI kernel stdev in voxels (mm if negative) [-2.5]
    -lssd_weig <float>	| SSD distance weight <float> [0.0]
    -ldef_weig <float>	| DEF distance weight <float> [0.0]
    -lncc_weig <float>	| NCC distance weight <float> [1.0]
    -t1dti_weig <float>	| T1DTI distance weight <float> [0.0]
    -temper <float>	    | Kernel temperature <float> [0.15]
    -sort_beta <float>	| The beta scaling factor (defined in xml) [0.5]
    -sort_numb <char>	| The number of elements in the sort (defined in xml) [7]

  * * * * * * * * * * * Reg Options * * * * * * * * * * * * * * * * * * * * * *

    -regAff <aff.txt>	| Input affine file from database to target
    -affOnly         	| Only run the affine and then stop (for nipype)
    -regNMI 		| Ust NMI as a registration similarity, instead of LNCC
    -regBE <float>	| Bending energy value for the registration [0.005]
    -regJL <float>	| Jacobian log value for the registration [0.0001]
    -regSL		| Skip the second Level non-rigid registration

  * * * * * * * * * * * Seg Options * * * * * * * * * * * * * * * * * * * * * *

    -segRF <fl1> <fl1>	| Relax Priors (fl1 = relax factor, fl2 = gauss std) [0,0]
    -segMRF <float> 	| The segmentation MRF beta value [0.15]
    -segPT <float> 	| The segmentation prior threhsold [0.2]
    -segIter <int> 	| The minimum number of iterationss [3]

  * * * * * * * * * *
```