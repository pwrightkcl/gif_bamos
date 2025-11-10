# GIF and BaMoS scripts

These scripts were originally written for the RISAPS project to run on the AI Centre cluster at the BMEIS. They ran in a
Docker container that included compiled versions of GIF and BaMoS, along with their dependencies. See the [docker](../docker)
directory for details of the Docker image.

## Installing GIF and BaMoS

See [docker](../docker).

## Running GIF and BaMoS

The scripts here are designed to be submitted to the RunAI system to run in a Docker image. The `submit` scripts contain
 the RunAI submit command and run the `run` scripts, which are bash wrappers to the various steps of the analysis. The 
`run` scripts could be adapted to run on their own.

The BaMoS scripts were adapted from here: https://github.com/csudre/BaMoS

You will need to update some of the fixed paths in the script to match your project.

### Reference images

GIF needs a database to run. Since this includes images that are subject to license, you will need to source an 
approved copy for your project.

BaMoS uses ICBM template images. These probably came originally from [UCLA BMAP](http://www.bmap.ucla.edu/portfolio/atlases) 
or [LONI](https://www.loni.usc.edu/research/atlas_downloads) but I'm uploading our versions since they have are 
slightly difference (image dimensions, cropping, division of tissue classes).

## Post-processing scripts

### Correction script:

```bash
python2.7 ~/Scripts/correction_lesions.py -les ${Lesion} -connect ${Connect} -label ${Label} -parc ${Parc} -corr choroid cortex sheet -id ${ID}
```

* Lesion: image output by BaMoS named `Correct_WS3WT3WC1Lesion_$ID_corr.nii.gz`
* Connect: image output by BaMoS named `Connect_WS3WT3WC1Lesion_$ID_corr.nii.gz`
* Label: text output by BaMoS named `TxtLesion_WS3WT3WC1Lesion_$ID_corr.txt`
* Parc: image output by GIF (copied to BaMoS output directory) named `GIF_Parcellation_$ID.nii.gz`
* ID: the same subject ID used in previous steps
* The arguments for `-corr` define which anatomic structures to correct; pass them as is.

### Laplace Lobes script

Works out regional volumes.

```bash
~/Scripts/LaplaceLobesScripts.sh ${PathResults} ${ID} ${PathGIF} ${PathToLesion} ${PathT1}
```

* PathResults: path to BaMoS output
* ID: the same subject ID used in previous steps
* PathGIF: path to GIF output
* PathToLesion: path to corrected lesion image
* PathT1: path to T1 image

## Follow-up scripts

The MATLAB scripts are used to review the results and extract summary statistics.

* `check_images.m`
  * Generates images for visual checking of segmentation results.
* `get_stats.m`
  * Extracts summary statistics from segmentation results.
* `get_full_stats.m`
  * Extracts more detailed statistics from segmentation results.

## Usage texts

### GIF

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
    -temper <float>	| Kernel emperature <float> [0.15]
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

###  BaMoS Statistical Segmentation

```text
  Usage ->	Seg_BiASM -in <int number of images> <filename1> <filename2> [OPTIONS]

  * * * * * * * * * * * * * * * * * Mandatory * * * * * * * * * * * * * * * * * *

	-in <number of images to segment> <filename1> <filename2>		| Filename of the input image
	-out <number of outputs> <filename1> <filename2>		| Filename1 with all leaves of the segmented image and Filename2 with only general classes
				| The input images should be 3D images.
  		- Select one of the following (mutually exclusive) -

	-priors <n> <fnames>	| The number of priors (n>0) and their filenames. Priors should be registered to the input images
				| Priors are mandatory for now. Won't be in the next release.
	-nopriors <n>		| The number of classes (n>0) 

	-txt_in <filename> 	| Name of the file containing all informations to recreate Tree. Usually used in combination with DP options to rework on current model obtained 
.	-txt_out <filename> 	| Name of the file under which to store information on the result once everything performed 
  * * * * * * * * * * * * * * * * GENERAL OPTIONS * * * * * * * * * * * * * * * * *

	-mask <filename>	| Filename of the brain-mask of the input image
	-quantMax <float between 0 and 1>	| Percentage of voxels to consider as high outliers (default=0.99) 
	-max_iter <int>		| Maximum number of iterations (default = 100)
	-min_iter <int>		| Minimum number of iterations (default = 6)
	-norm_thresh <float>	| Threshold used for stop for EM convergence when not applying BF correction
	-BiASM <bool> 		 BiASM run ON [1] or OFF [0]. Default is ON
	-quantMin <float> : 	 | Value between 0 and 1 indicating the lower threshold for the intensities quantile cut off (default is 0) 
	-quantMax <float> : 	 | Value between 0 and 1 indicating the upper threshold for the intensities quantile cut off. -quantMax must be higher than -quantMin (default is 1) 
	-splitAccept <int> 		 | Value deciding about the behavior to adopt when wanting to split a small class 
		 0 : if the class weight is under weightMini/5 relative to main Node, the split operation cannot be performed and the EMf is not continued 
		 1 : if the class weight is under weightMini/5 relative to main Node, the split operation cannot be performed but the EM is still conducted and the operation checked for acceptance 
		 other : the split operation is conducted whatever the weight for the class to split 
	-in_DC <filename>	| Filename of the data already corrected and log-transformed to be used for the analysis
	-priorDGM <filename>	| Filename of the priors to belong to the DGM. Required if doing the correction for juxtacortical lesions
	-juxtaCorr <bool>	| Flag for juxtacortical correction (default=0)
	-progMod <number of steps> <number of modalities to add per step>	| Indicates whether the modalities should be considered all together or progressively. Recommanded: 0 for 2 modalities; 2 2 1 for 3 modalities
	-averageIO <weight> <Filename atlas inlier> <Filename atlas outlier>	| Indicates filenames to use as I/O atlases. Weight give the importance attributed to inlier atlas
	-averageGC <weight> <Filename segmentation1> <Filename segmentation2>	| Indicates filenames to use as I/O atlases. Weight give the importance attributed to inlier atlas
 * * * * BIAS FIELD (BF) CORRECTION OPTIONS * * * * 

	-max_iterBF <int>		| Maximum number of iterations used for the BF correction (default = 100)
	-bc_order <int>		| Polynomial order for the bias field [off = 0, max = 5] (default = 3) 
	-bc_thresh <float>	| Bias field correction will run only if the ratio of improvement is below bc_thresh (default=0 [OFF]) 
	-bf_out <filename>	| Output the bias field image
	-bc_out <filename>	| Output the bias corrected image. If not provided automatically given and saved anyway under DataCorrected_${nameoutpu}

	-BFP <bool>	| Boolean flag to indicate if bias field should be progressive

 * * * * Options on the BiASM part * * * * 

	-init_split <int> 	| Choice of type of initialisation wanted for the split operation. NOT IN USE CURRENTLY 
.	-CEM <bool> 0 for OFF, 1 for ON 	| Flag on application of classification EM for the BiASM steps : 
 EM embedded for each general class is only applied on the voxels classified in general class by current hard segmentation 
	-AtlasWeight <number of inputs> <list float between 0 and 1> 	| Weight attributed to the current smoothed segmentation when readapting the priors. Choose 0 to avoid any change of the statistical atlases (default = 0). A different weighting can be chose at each level. If only one value is given, the same value is applied at all levels
	-AtlasSmoothing <number of inputs > <list of floats> 	 | Standard deviation attributed to the Gaussian filter used to smooth current segmentation when modifying atlases (default = 0.3) 
	-KernelSize <int> 	| Size of the kernel to use for the gaussian filter used for the modification of the atlases (default = 3) 
	-PriorsKept <int> 	|Choice on the behavior to adopt concerning the statistical atlases
		 0 : The statistical atlases are not kept after the first of the EM algorithm 
		 1 : Default choice. The statistical atlases are not modified throughout the algorithm 
		 2 : The statistical atlases are replaced by a smoothed version of the segmentation result from EM first. To be used only with an outlier model in order to use a robust enough initial segmentation 
		 3 : The statistical atlases are replaced by a smoothed version of the segmentation result each type a new model is accepted 
		 4 : To be used only in conjonction with uniform type change case 5. The statistical atlases at the first level are replaced only after EM first by the smoothed version of the segmentation result. The atlases related to the outliers subclasses (Level 2) are replaced by their segmentation result before normalisation each time a new model is accepted 
	-SMOrder <int> 	| Type of ordering of the split and merge operations list 0 for the diagonal order, 1 for the vertical one (default = 1)
	-CommonChanges <bool> 0 for OFF, 1 for ON 	| Flag on authorising operations on more than one general class at a time. Option only available if the vertical order has been chosen (default = 0) 

	-acceptType <int> : 	| Under what conditions a change in the BIC induces a change in the model
		 0 : The change is authorised as soon as BICnew > BICold
		 1 : And above : default behavior: the change is accepted only if relative change is above acceptance threshold set up with -accept_thresh
	-accept_thresh <float> : 	| Value of the threshold above which the relative change in BIC will lead to the acceptation of the new model if the -acceptType 1 is chosen. Default value is 1E-5 
	-deleteUW <bool> : 	 | Behavior adopted with subclasses with very low weight. 1 to put it ON, 0 for OFF. By default ON. Delete the subclasses whose weight relative to their general class is below minimum weight after accepting a model	-miniW <float> : 	 | Value of the minimal weight for a subclass relative to its general class (Level 1). The model modification is not accepted if one of the gaussian distribution stemming from the model change is underweight. Same value used when the option -deleteUW is ON. (default = 0.01)
	-BICFP <bool> : 	 | Choice for the definition of the number of free parameters when calculating the BIC. 0 without mixing coefficients, 1 with (default=1)
* * * * Options when using known knowledge or influencing current classes number with known distribution * * * *

	-DP <int> <filename1> ,<filename2>... int with number of filenames to count and then the names of the corresponding filenames 	| Filenames with the number of subclasses in the used distributions 
.	-DistClassInd <bool> 0 if NO, 1 if YES 	| If subclass distribution count provided, should we considered the general classes independent or not. Non independence aspect only possible if only 1 DP file is provided. Otherwise independent by default 
If only 1 file is used, distributions have to be read as lines of the file (1 line per general class) and the file is to be used as a description of the population. When more than 1 file is available, means we are using Count Files and not population description
Therefore with more than 1 file, only the independent DP option is available
	 WARNING With -DP, the order of the filenames (or of the lines if only one file is used) must be consistent with the order of the general classes set in the priors or elsewhere 
	-Count <int> <List of filenames> 	| int number of general classes (must be coherent with the rest of the options) and the subsequent list of filenames where to store the count of the different subclasses 
Used to record for each run of BiASM on a population the number of subclasses obtained for each general class. Each file correspond to a general class 
 	-smoothing_order <int> 	| Type of smoothing imposed to the categorical distribution brought by the -DP option when considered independent
		 0 : Simple Gaussian filtering 
		 >1 : Smoothing applying Simonoff method with Poisson regularisation 
	-BWfactor <float> 	| Factor to use to modify the bandwidth calculation when smoothing the categorical distribution indepedently 
	-DPGauss_std <float> 	| Standard deviation to use for the Gaussian blurring when using the non independent option for the distribution knowledge 
	-Countmod <bool> 

* * * * OPTIONS ON POSSIBLE OUTLIER MODEL * * * * 

	-outliersM <int> 	|Choice among the different outliers model :
		 0 : By default, no outliers model considered		 1 : Model where a classical mixture between outliers and inliers is considered at the first level and the priors for the general classes are set up at the second level 2 : Model where a class of outliers is considered at the same level as the other general classes (GM WM CSF) more easily used	-outliersW <float> 	| Value of the lambda chosen to define the probability to belong to the outlier class	-uniformTC <int> 	|Choice of the behavior to adopt when in presence of a uniform distribution to split
		 0 : The uniform distribution is transformed into a gaussian distribution
		 2 : The uniform distribution is transformed into 2 gaussian distributions  as in the classical gaussian case
		 3 : The uniform distribution is transformed into 1 gaussian and 1 uniform distribution and a new node at level 1 is created for each gaussian newly formed. A statistical atlas is given and comes from the smoothed segmentation of the uniform class
		 4 : The uniform distribution is transformed into 1 gaussian and 1 uniform at level 2 under the outlier node and a classical mixture is considered under the outlier node 
		 5 : The uniform distribution is transformed into 1 gaussian and 1 uniform at level 2 but following atlases originating from the parameters initialisation of the newly formed gaussian.
	-unifSplitW <float> 	| Value of the weight given to the uniform distribution when split into 1 gaussian distribution and a new uniform distribution. Only needed in case of -uniformTC=2 or 4	-varInitUnif <int> : 	|Choice of the type of variance initialisation to adopt for the gaussian distribution when splitting a uniform distribution for -uniformTC >= 3 
		 0 : The value of the initial mean corresponds to the first maximum of the blurred histogram corresponding to the uniform distribution. All values of the variance calculated for the class under the uniform distribution divided by 10 
		 1 : The parameters of the newly formed gaussian distribution are chosen among the results of a kmeans classification with k=2 for the uniform distribution. The choice of the parameters among the results is defined with -init_splitUnif 
		 >1 : By default, the initial mean is the maximum of the blurred histogram and the variance is set isotropic taking as value the minimum between the size of one bin of the histogram and the calculated variance divided by two
-init_splitUnif <int> 	| Choice of the parameters to use to initialise the newly formed gaussian distribution when using the kmeans classification to define the parameters (choice 1 for -varInitUnif)
		 0 : The parameters with the smallest determinant for the variance are chosen for the new gaussian distribution
		 1 : Default. The parameters corresponding to the heavier subclass is chosen even if it corresponds to a large variance-miniW <float> 	| Minimal weight for which a subclass is allowed to be created. Has to be between 0.001 and 0.1 (default=0.01)
-CovPriors <int> 	| Choice of behavior to adopt for the constraint overt the covariance matrix
-TypicalityAtlas <bool> 	| Indicates if a typicality atlas should be created to enhance the sensitivity to outliers
-VLkappa <float> 	| Mahalanobis threshold used to build the typicality atlas (default=3)
* * * * MRF OPTIONS * * * * 

	-MRF <int> 	| Choice among 4 different options about types of MRF we might use  
		 0 : By default no MRF applied. Way of putting MRF OFF 
		 1 : MRF applied during the obtention of the model
		 2 : MRF applied a posteriori on a last EM run after convergence of the model
		 3 : MRF applied both during the obtention of the model and once afterwards (With G Matrix or not, possibly different)
	-GMRF <filename> 	| Setting of the G matrix to use with the MRF application. Informations for the neighborhood relationships and the value in the G matrix when MRF applied in the obtention of the model
	-GMRFPost <filename> 	| Gives the filename to use to obtain information for construction of GMatrix used a posteriori for an MRF 
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
```

### BaMoS Segmentation Analysis

```text
  EM Segmentation Analysis:
  Usage ->	Seg_Analysis -in <filename1> [OPTIONS]


  BaMoS Segmentation Analysis:
  Usage ->	Seg_Analysis -in <filename1> [OPTIONS]

  * * * * * * * * * * * * * * * * * Mandatory * * * * * * * * * * * * * * * * * *

	-in <filename1> 		| Filename of the segmentation result to analyse
				| The input image should be 2D, 3D or 4D images. 2D images should be on the XY plane.
* * * * OPTIONS FOR RECONSTRUCTION OF THE MODEL * * * * 

	-inTxt2 <filename1> <filename2>		| Filenames containing the information on the tree structure (filename1) and the corresponding 4D image (filename2) for reconstruction of the model
	-inChangePath <PathString> 		| Path to the folder where all model files are stored (Tree structure, Tree classes, Mask, Corrected Data
	-output_dir <PathString> 		| Path to the folder where all output files should be saved
	-inModa <int> <list of ints> 		| Indicates the modalities to be considered in the model, first the number of modalities then there encoding
		 1 : T1
		 2 : T2
		 3 : FLAIR
		 4 : PD

* * * * NEEDED DATA FOR NEW LESION SEGMENTATION * * * * 

	-inPriorsCGM <filename> 		| Filename of atlas CGM
	-inPriorsDGM <filename> 		| Filename of atlas DGM
	-inPriorsECSF <filename> 		| Filename of atlas ECSF
	-inPriorsICSF <filename> 		| Filename of atlas ICSF
	-inPriorsWM <filename> 		| Filename of atlas WM
	-inPriorsOut <filename> 		| Filename of atlas Out (NB)

* * * * OPTIONS FOR CORRECTION OF LESION SEGMENTATION / NEW LESION * * * * 

	-inCST <filename> 		| Filename of atlas of corticospinal tracts
	-typeVentrSeg <bool> 		| Flag indicating that the ventricles will be segmented using the parcellation results 
	-inVentrSeg <filename> 		| Filename for an already created ventricle segmentation 
	-ParcellationIn <filename> 		| Filename of parcellation file (required when typeVentrSeg=1) 
	-inArtefact <filename> 		| Filename of artefact image to avoid some areas to be considered as lesions 
	-WeightedSeg <int1> <float> <int3> 		| The first input concerns the type of Mahalanobis weighting adopted, the second input is the Mahalanobis threshold (default=3), and the third the class used for the comparison (default =1)
	-Edginess float 		| Edginess threshold to be used (default = 0)
	-SegType <int>  		| Type of segmentation strategy to adopt
	-SP <bool>  		| Flag for initial septum pellucidum correction (default=0)
	-CorrIV <bool>  		| Flag for correction of inside ventricles artefacts (default=1) 
	-TO <bool> 		 | Flag to account for all outliers and do the post-processing at the voxel level (default=0)
	-juxtaCorr <bool> 		 | Flag to try and correct for island of GM 
	-correct 		 | if indicated signals that the correction of lesion should be performed 
	-connect 		 | if indicated signals that the connected elements should be obtained 
	-Simple 		 | if indicated signals that a 3D image should be simply determined for potential lesion (and not 4D one for each outlier class as originally)
* * * * OPTIONS FOR SPECIFIC OUTPUTS / SOME HAVE TO BE RUN INDEPENDENTLY OF LESION SEGMENTATION * * * * 

	-WMMaps <bool> 		 | Flag indicating that the Mahalanobis distance should be calculated 
	-IO <bool> 		 | Flag indicating if the inlier/outlier segmentation should be output 
	-Euc <bool> 		 | Flag indicating that the euclidean distance from given mask (through inLes or inLesCorr) must be output 
* * * * OPTIONS FOR LAPLACE LAYERS BUILDING AND LOCAL SUMMARY * * * * 

*** Creation of the Distance maps from the lobar segmentation (requires -inLobes -inLesCorr (can be the full T1 image but must be float datatype) and -mask
	-inLobes <integer> <list filenames> 		 | Number of lobar masks and corresponding files to build the corresponding distance map. 
*** Creation of Local summary 
 	-LS <bool> 		 | Flag indicating that the local summary should be performed 
	-inQuadrant <filename> 		 | Filename where the zonal separation is stored (in lobes but historically in quadrants) 
	-inLes <filename> 		 | Filename with the lesion segmentation to assess locally (alternatively can use -inLesCorr) 
	-LaplaceNormSol <filename> 		 | Filename of the layer discretisation 
*** Creation of Laplace based layers 
	-LapIO <infile> <outfile> 		 | Names of the two binary segmentation used to delineate the borders of the volume on which to build the Laplace solution. 
	-nameLap <string> 		 | name to include in the Laplace layer formulation of file saving
	-numbLaminae <integer> <list of integers> 		 | number of layer numbers to calculate followed by the list of number of layers to calculate over the obtained normalised distance 

* * * * POSSIBLE RUN THAT DO NOT REQUIRE BAMOS MODEL * * * * 

*** Getting Seg vs Ref statistics for a set of segmentations. The process provides a text file with for each comparison a line with :Name,VolRef,VolSeg,LabelRef,LabelSeg,FP,FN,TP,DSC,AvDist,DE,DEFP,DEFN,OEFP,OEFN,OER,VD,TPR,FPR,TPRc,FPRc,FNRc
	 -inMaskVec <number of masks> <list of mask filenames> 		 | indicates the number of masks to use and the list of the associated names (note that the masks must be in binary format)
	 -inLesVec <number of Seg> <list of seg filenames> 		 | indicates the number of segmentations to evaluate and the names of the corresponding files. Must be same number as number of masks 
	 -inRefVec <number of Ref> <list of reference filenames> 		 | indicates the number of reference images and the corresponding filenames. Must be the same number as inLesVec and inMaskVec 
	 -inNamesVec <number of Names> <list of names to give> 		 | indicates the number of evaluations and the name attributed to each
	 -outFile <name of file> 		 | Name of the file in which the results of the evaluation will be printed 

*** Creating the intensity matching output automatically a text file with the polynomial coefficient for each matching pair and the matched transformed images. 
	 -maskMatch <mask filename> 		| Name of mask file (binary) over which the intensity matching will be made 
	 -matchFloat <number of images to match> <filenames> 		 | Number of files to match and corresponding list of filenames 
	 -matchRef <number of reference images> <filenames> 		 | Number of reference images for the matching and corresponding list of files (should be same number in ref and float)
	 -orderFit <integer> 		 | Order of the polynomial fit performed 

*** Averaging images together 
	-outMean <filename> 		 | indicates the name of the output file containing the result of the averaging 
	-meanImages <integer> <filenames> | number of images to average and corresponding filenames 

* * * * * NEEDED OPTIONS FOR SIMULATION GENERATION * * * * 

*** Generation of Bias field images 
	-BFGen <float1> <float2> <float3> 		 | 3 float values to generate random bias field with first value the maximum order, the second the number of modalities and the third the max of range of coefficients 
	-BFGenText <textfile> 		 | Filename for textfile where coefficients of BF are stored 

*** Generation of random affine transformation
	-AffGen <float> <float> 		 | 2 float values with the range of rotation in degrees for random choice and range of translation 
	-OutFile <filename> 		 | Filename for the output (text file for the rigid transformation) 
	-HS <filename> 	| Requirement for hard segmentation with filename to store it
	-DCh	| Allows for calculation of the hard Dice coefficient 
	-DCs	| Allows for calculation of the soft Dice coefficient 
	-TP	| Allows for calculation of the number of true positives 
	-TN	| Allows for calculation of the number of true negatives 
	-FP	| Allows for calculation of the number of false positives 
	-FN	| Allows for calculation of the number of false negatives 
	-mask <filename>	| Filename of the brain-mask of the input image
	-compJoint <filename>	| Filename of the segmentation to compare it to. Must contain the same number of classes
	-compMult <numberOfPartialSeg> <filename> ... <filename>	| Number of files to form the segmentation result with their filenames. Must contain the same number of classes
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
```