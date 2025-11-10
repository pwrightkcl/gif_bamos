#!/bin/bash

#### WARNING !!!! THIS SCRIPT ASSUMES THAT THE FLAIR IMAGE WILL BE REGISTERED TO THE T1 IMAGE.
#### ALL RESULTS SHOULD BE VISUALISED IN THE T1 SPACE. ALL SCANS ARE PUT IN THE RAS ORIENTATION BY DEFAULT

###################
# Parse arguments #
###################

if [ $# -lt 5 ] || [ $# -gt 9 ]
then
	usage
fi

usage () {
  cat <<HELP_USAGE
Usage: $(basename "$0") ID ImageFLAIR ImageT1 GIF_results_path PathResults [JUMP_START] [Opt] [Mem] [Space]
  ID                String identifying the image(s)
  ImageFLAIR        FLAIR image file
  ImageT1           T1 image file
  GIF_results_path  Path to existing GIF results
  PathResults       Path where BaMoS results should be saved
  JUMP_START        Set to 1 if you already did registration of ICBM template, creation of ICBM atlases,
                    and Segmentation SegBiASM
  Opt               Suffix for the Seg_BiASM output file
  Mem               Memory in G for qsub tmem and h_vmem arguments
  Space             Set to >1 to use FLAIR space instead of T1
HELP_USAGE
  exit 0
}

ID=$1
ImageFLAIR=$2
ImageT1=$3
GIF_results_path=$4
PathResults=$5
if [ -z "${6}" ]
then
  JUMP_START=0
else
  JUMP_START=$6
fi
if [ -z "${7}" ]
then
  Opt=""
else
  Opt=$7
fi

#Mem=$8
if [ -z "${9}" ]
then
  Space=1
else
  Space=$9
fi

if [ ! -d "$PathResults" ]
then
    mkdir "$PathResults"
fi

########################
# Hard-coded variables #
########################

# AtlasWeight argument for Seg_BiASM
AW=0

# juxtaCorr argument for Seg_BiASM and Seg_Analysis in lesion segmentation
JC=0

# maxRunEM argument for Seg_BiASM
MRE=250

# SP argument for Seg_Analysis in lesion segmentation, refined correction for third ventricle, and getting DGM segmentation from GIF.
OptSP=0

# LevelCorrection argument for Seg_Analysis in lesion segmentation, refined correction for third ventricle, and getting DGM segmentation from GIF.
OptCL=2

# LesWMI argument for Seg_Analysis in lesion segmentation, refined correction for third ventricle, and getting DGM segmentation from GIF.
OptWMI=2 # If >0, indicates that a higher level of sensitivity to lesion should be considered from voxels coming from WMI

# Used in second Seg_Analysis call, but never defined. Defining as empty here just to clear "used but not defined" warning.
OptInfarcts=""

# typeVentrSeg argument for Seg_Analysis in lesion segmentation
TVS=1

# Voxel values in GIF parcellation that are used in the artefact mask for refined correction of third ventricle, filename Artefacts_${ID}.nii.gz
ListCorr=(101 102 103 104 105 106 187 188 47 48 49 32 33 173 174)

# Voxel values in GIF parcellation that are used to make an artefact mask, filename ${ID}_Artefacts.nii.gz
ArtefactArray=(5   12  24  31  39  40  50  51  62  63  64  65  72  73  74  48  49  101 102 105 106 139 140 187 188 167
               168 39  40  117 118 123 124 125 126 133 134 137 138 141 142 147 148 155 156 181 182 185 186 187 188 201
               202 203 204 207 208)

# Modalities to put in Seg_BiASM and Seg_Analysis
ArrayModalities=("T1" "T2" "FLAIR" "PD" "SWI") # Canonical modality array
arrayMod=("T1" "FLAIR" ) # Selected modalities
ModalitiesTot=T1FLAIR # Used to name the outputs from Seg_BiASM, which are also inputs to Seg_Analysis.
# The modality strings are used to construct filenames for Seg_BiASM argument -in (assumed to be two).
# The numeric positions of selected modalities in canonical array are used to form Seg_Analysis argument -inModa.

# outliersW argument for Seg_BiASM.
OW=0.01

# juxtaCorr argument for Seg_BiASM and Seg_Analysis in lesion segmentation.
JC=1

# SP argument for Seg_Analysis in lesion segmentation, refined correction for third ventricle, and getting DGM segmentation from GIF.
OptSP=1

# TypicalityAtlas argument for Seg_BiASM
OptTA=1

# Added to certain filenames in correction for septum pellucidum and refined correction for third ventricle.
OptTxt=Test

# Flags for levels of correction
flag_corrDGM=1

# Environment paths
PathReg=/usr/local/bin
PathSeg=/usr/local/bin
PathICBM=/nfs/project/RISAPS/sourcedata/ICBM_priors
ScratchRoot=/tmp
PathScripts=/nfs/project/RISAPS/code/scripts

# Additional input files
RuleFileName=$PathScripts/GenericRule_CSF.txt
NameGMatrix=$PathScripts/GMatrix4_Low3.txt

###########
# Execute #
###########

NameScript=${PathResults}/ScriptBaMoS_${ID}_${Opt}.sh
echo "Creating local script:"
echo "$NameScript"
echo '#!/bin/bash' > "$NameScript"
chmod +x "$NameScript"

PathScratch=${ScratchRoot}/${ID}_BaMoSCross_${Opt}_${JOB_ID}
echo "echo \"Scratch path: $PathScratch\"" >> "$NameScript"
echo "mkdir -p ${PathScratch} " >> "$NameScript"
ChangePathString="-inChangePath ${PathScratch}/"

{
  echo "cp ${PathResults}/* ${PathScratch}/."

  echo "echo \"Copying T1 image and converting to float.\""
  echo "cp ${ImageT1} ${PathScratch}/T1_${ID}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/T1_${ID}.nii.gz -odt float ${PathScratch}/T1_${ID}.nii.gz"

  echo "echo \"Aligning FLAIR to T1.\""
  echo "${PathReg}/reg_aladin -ref ${PathScratch}/T1_${ID}.nii.gz -flo ${ImageFLAIR} \
                              -aff ${PathScratch}/Aff_FLAIRtoT1.txt -res ${PathScratch}/FLAIR_${ID}.nii.gz -rigOnly"
  echo "${PathSeg}/seg_maths ${PathScratch}/FLAIR_${ID}.nii.gz -odt float ${PathScratch}/FLAIR_${ID}.nii.gz"
} >> "$NameScript"

# The original BaMoS script assumed GIF creates a TIV image, but this is not always the case. These lines look for a GIF
# TIV and copy it, or create a new one if it does not exist.
tivs=("$GIF_results_path"/*TIV*)
if (( ${#tivs[@]} > 0 ))
then
  if (( ${#tivs[@]} > 1 ))
  then
    echo "Multiple TIV files in GIF results path. Using the first of the following:"
    echo "${tivs[@]}"
  fi
  tiv=${tivs[0]}
  echo "cp $tiv ${PathScratch}/Mask_${ID}.nii.gz" >> "$NameScript"
else
  echo "echo \"Creating TIV mask.\"" >> "$NameScript"
  parcs=("$GIF_results_path"/*NeuroMorph_Parcellation.nii.gz)
  if (( ${#parcs[@]} == 0 ))
  then
    echo "No GIF parcellation found in ${GIF_results_path}."
    exit 1
  elif (( ${#parcs[@]} > 1 ))
  then
    printf "More than one GIF Parcellation found in %s.\nUsing first of the following:\n" "$GIF_results_path"
    echo "${parcs[@]}"
  fi
  parc=${parcs[0]}
  echo "seg_maths \"$parc/\" -thr 3.5 -bin ${PathScratch}/Mask_${ID}.nii.gz" >> "$NameScript"
fi

{
  echo "${PathSeg}/seg_maths ${PathScratch}/Mask_${ID}.nii.gz -bin -odt char ${PathScratch}/GIF_B1_${ID}.nii.gz"
#  echo "cp ${PathScratch}/GIF_B1_${ID}.nii.gz ${PathScratch}/GIF_${ID}_B1.nii.gz"

  echo "echo \"Copying GIF priors.\""
  echo "cp ${GIF_results_path}/*prior* ${PathScratch}/GIF_prior_${ID}.nii.gz"
} >> "$NameScript"

if ((Space>1))
then
  {
    echo "echo \"Aligning images to FLAIR space.\""
    echo "cp ${ImageFLAIR} ${PathScratch}/FLAIR_${ID}.nii.gz"
    echo "${PathSeg}/seg_maths ${PathScratch}/FLAIR_${ID}.nii.gz -odt float ${PathScratch}/FLAIR_${ID}.nii.gz"

    echo "echo \"Aligning T1 image to FLAIR.\""
    echo "${PathReg}/reg_aladin -ref ${PathScratch}/FLAIR_${ID}.nii.gz -flo ${ImageT1} \
                                -aff ${PathScratch}/Aff_T1toFLAIR.txt -res ${PathScratch}/T1_${ID}.nii.gz -rigOnly"
    echo "${PathSeg}/seg_maths ${PathScratch}/T1_${ID}.nii.gz -odt float ${PathScratch}/T1_${ID}.nii.gz"

    echo "echo \"Resampling GIF results to FLAIR space.\""
  } >> "$NameScript"
  for p in Segmentation prior Parcellation
  do
    {
    echo "${PathReg}/reg_resample -inter 1 -flo ${GIF_results_path}/*${p}* -res ${PathScratch}/GIF_${p}_${ID}.nii.gz \
                                   -ref ${PathScratch}/FLAIR_${ID}.nii.gz -aff ${PathScratch}/Aff_T1toFLAIR.txt"
#    echo "cp ${PathScratch}/GIF_${p}_${ID}.nii.gz ${PathScratch}/GIF_${ID}_${p}.nii.gz"
    } >> "$NameScript"
  done
  {
    echo "echo \"Resampling TIV mask to FLAIR space.\""
    echo "${PathReg}/reg_resample -inter 1 -flo ${PathScratch}/GIF_B1_${ID}.nii.gz \
                                  -res ${PathScratch}/GIF_B1_${ID}_res.nii.gz -ref ${PathScratch}/FLAIR_${ID}.nii.gz \
                                  -aff ${PathScratch}/Aff_T1toFLAIR.txt"
    echo "mv ${PathScratch}/GIF_B1_${ID}_res.nii.gz ${PathScratch}/GIF_B1_${ID}.nii.gz"
#    echo "cp ${PathScratch}/GIF_B1_${ID}.nii.gz ${PathScratch}/GIF_${ID}_B1.nii.gz"
  } >> "$NameScript"
else
  echo "echo \"Copying GIF results.\"" >> "$NameScript"
  for p in Segmentation prior Parcellation
  do
    echo "cp ${GIF_results_path}/*${p}* ${PathScratch}/GIF_${p}_${ID}.nii.gz" >> "$NameScript"
#    echo "cp ${GIF_results_path}/*${p}* ${PathScratch}/GIF_${ID}_${p}.nii.gz" >> "$NameScript"
  done
fi
{
  echo "echo \"Copying scratch directory to results directory.\""
  echo "cp ${PathScratch}/* ${PathResults}/."

  echo "echo \"Extracting volumes from GIF prior.\""
} >> "$NameScript"
PriorsArray=("Out" "CSF" "CGM" "WMI" "DGM" "Brainstem")
for ((p=0;p<6;p++))
do
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_prior* -tp ${p} ${PathScratch}/GIF_${PriorsArray[p]}_${ID}.nii.gz" >> "$NameScript"
done

echo "echo \"Creating artefact mask based on GIF parcellation.\"" >> "$NameScript"
if ((${#ArtefactArray[@]}>0))
then
  stringAddition="${PathScratch}/${ID}_ArtConstruction_0.nii.gz "
  for ((i=0;i<${#ArtefactArray[@]};i++))
  do
    Value=${ArtefactArray[i]}
    ValueMin=$(echo "$Value - 0.5" | bc -l)
    ValueMax=$(echo "$Value + 0.5" | bc -l)
    echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr $ValueMin -uthr $ValueMax -bin ${PathScratch}/${ID}_ArtConstruction_${i}.nii.gz" >> "$NameScript"
    stringAddition="${stringAddition} -add ${PathScratch}/${ID}_ArtConstruction_${i}.nii.gz "
  done
  echo "${PathSeg}/seg_maths ${stringAddition} -bin ${PathScratch}/${ID}_Artefacts.nii.gz" >> "$NameScript"
fi
echo "rm ${PathScratch}/*_ArtConstruction_*" >> "$NameScript"

if [ -z "$JUMP_START" ] || [ "$JUMP_START" -eq 0 ]
then
  {
    echo "echo \"Aligning ICBM template to T1.\""
    echo "${PathReg}/reg_aladin -ref ${PathScratch}/T1_${ID}.nii.gz -flo ${PathICBM}/ICBM_Template.nii.gz \
                                -aff ${PathScratch}/${ID}_AffTransf.txt"
    echo "${PathReg}/reg_f3d -ref ${PathScratch}/T1_${ID}.nii.gz -flo ${PathICBM}/ICBM_Template.nii.gz \
                             -aff ${PathScratch}/${ID}_AffTransf.txt -cpp ${PathScratch}/${ID}_cpp.nii.gz"
    echo "cp ${PathScratch}/*cpp* ${PathResults}/."
  } >> "$NameScript"
fi

echo "echo \"Creating ICBM masks.\"" >> "$NameScript"
for p in CGM DGM ECSF ICSF Out WM
do
  echo "${PathReg}/reg_resample -ref ${PathScratch}/T1_${ID}.nii.gz -flo ${PathICBM}/ICBM_${p}.nii.gz -cpp ${PathScratch}/${ID}_cpp.nii.gz -res ${PathScratch}/ICBM_${p}_${ID}.nii.gz" >> "$NameScript"
done
{
  echo "${PathSeg}/seg_maths ${PathScratch}/ICBM_DGM_${ID}.nii.gz -add ${PathScratch}/ICBM_CGM_${ID}.nii.gz \
                             ${PathScratch}/ICBM_GM_${ID}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/ICBM_ICSF_${ID}.nii.gz -add ${PathScratch}/ICBM_ECSF_${ID}.nii.gz \
                             ${PathScratch}/ICBM_CSFs_${ID}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/ICBM_DGM_${ID}.nii.gz -bin -mul ${PathScratch}/GIF_DGM_${ID}.nii.gz \
                             ${PathScratch}/GIF_DGM_${ID}_bis.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_CGM_${ID}.nii.gz -add ${PathScratch}/GIF_DGM_${ID}_bis.nii.gz \
                             ${PathScratch}/GIF_GM_${ID}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_DGM_${ID}.nii.gz -sub ${PathScratch}/GIF_DGM_${ID}_bis.nii.gz \
                             -add ${PathScratch}/GIF_WMI_${ID}.nii.gz ${PathScratch}/GIF_WMI_${ID}_bis.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_WMI_${ID}_bis.nii.gz -add ${PathScratch}/GIF_Brainstem_${ID}.nii.gz \
                             ${PathScratch}/GIF_WM_${ID}.nii.gz"
} >> "$NameScript"

if [ -z "$JUMP_START" ] || [ "$JUMP_START" -eq 0 ]
then
  echo "echo \"Preparing BaMoS Statistical Segmentation.\"" >> "$NameScript"
  arrayImage=()
  arrayModNumber=()
  echo "echo \"Modalities to put are ${arrayMod[*]}.\"" >> "$NameScript"
  # Find the positions of each element of arrayMod in ArrayModalities and store in arrayModNumber
  for ((m=0;m<${#arrayMod[@]};m++))
  do
    for ((pos=0;pos<${#ArrayModalities[@]};pos++))
    do
      TmpModa=${ArrayModalities[pos]}
      TmptestModa=${arrayMod[m]}
      Subtracted="${TmptestModa/$TmpModa}"
      if ((${#Subtracted}<${#TmptestModa}))
      then
        FinModa=$((pos+1))
        arrayModNumber=(${arrayModNumber[*]} $FinModa)
      fi
    done
    arrayImage=( "${arrayImage[*]}" "${PathScratch}/${arrayMod[m]}_${ID}.nii.gz" )
  done
  array_Priors=("${PathScratch}/GIF_GM_${ID}.nii.gz" "${PathScratch}/GIF_WM_${ID}.nii.gz" \
                "${PathScratch}/GIF_CSF_${ID}.nii.gz" "${PathScratch}/GIF_Out_${ID}.nii.gz")
  {
    echo "echo \"\""
    echo "echo \"****************************************\""
    echo "echo \"Running Seg_BiASM.\""
    # Line below assumes two input images. If other than two are in arrayMod, use "-in ${#arrayImage[@]} ${arrayImage[*]}"
    echo "${PathSeg}/Seg_BiASM -VLkappa 3 -in 2 ${arrayImage[*]} -priors 4 ${array_Priors[*]} \
                               -mask ${PathScratch}/GIF_B1_${ID}.nii.gz \
                               -out 2 ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.nii.gz \
                                      ${PathScratch}/${ModalitiesTot}_BiASMG_${ID}.nii.gz \
                               -txt_out ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.txt -bc_order 3 -CovPriors 8 \
                               -BFP 1 -maxRunEM ${MRE} -AtlasSmoothing 1 1 -AtlasWeight 1 ${AW}  -SMOrder 0 \
                               -KernelSize 3 -PriorsKept 5 -unifSplitW 0.5 -varInitUnif 1 -uniformTC 4 -deleteUW 1 \
                               -outliersM 3 -outliersW ${OW} -init_splitUnif 0 -splitAccept 0 -unifTot 1 -MRF 1 \
                               -GMRF ${NameGMatrix} -juxtaCorr ${JC} -progMod 0 \
                               -priorDGM ${PathScratch}/ICBM_DGM_${ID}.nii.gz -TypicalityAtlas ${OptTA}"
    echo "echo \"****************************************\""
    echo "echo \"\""
#    echo "rm ${PathScratch}/BG* ${PathScratch}/MRF*"
    echo "cp ${PathScratch}/T1FLAIR* ${PathResults}/. "
    echo "cp ${PathScratch}/Data*T1FLAIR* ${PathResults}/. "
  } >> "$NameScript"
fi

{
  echo "echo \"\""
  echo "echo \"****************************************\""
  echo "echo \"Running first Seg_Analysis.\""
  echo "${PathSeg}/Seg_Analysis -inTxt2 ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.txt \
                                ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.nii.gz \
                                -mask ${PathScratch}/GIF_B1_${ID}.nii.gz -Package 1 -SegType 1 -WeightedSeg 3 3 1 \
                                -connect -correct -inModa 2 1 3 -inRuleTxt ${RuleFileName} -WMCard 1 \
                                -inPriorsICSF ${PathScratch}/ICBM_ICSF_${ID}.nii.gz \
                                -inPriorsDGM ${PathScratch}/ICBM_DGM_${ID}.nii.gz \
                                -inPriorsCGM ${PathScratch}/ICBM_CGM_${ID}.nii.gz \
                                -inPriorsECSF ${PathScratch}/ICBM_ECSF_${ID}.nii.gz -TO 1 \
                                -ParcellationIn ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -typeVentrSeg ${TVS} \
                                -Simple -Secondary 60 -juxtaCorr ${JC}  -SP ${OptSP} -LevelCorrection ${OptCL} \
                                ${ChangePathString} -LesWMI ${OptWMI} -Neigh 18"
  echo "echo \"****************************************\""
  echo "echo \"\""
  echo "cp ${PathScratch}/LesionCorrected*WS3WT3WC1* ${PathScratch}/PrimaryLesions_${ID}.nii.gz"
  echo "cp ${PathScratch}/SecondaryCorrected*WS3WT3WC1* ${PathScratch}/SecondaryLesions_${ID}.nii.gz"
  echo "cp ${PathScratch}/Primary* ${PathResults}/. "
  echo "cp ${PathScratch}/Secondary* ${PathResults}/. "
#  echo "rm ${PathScratch}/DataR* ${PathScratch}/LesionT* ${PathScratch}/Summ*"

  echo "echo \"Correcting for septum pellucidum.\""
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 65.5 -uthr 67.5 -bin \
                             ${PathScratch}/VentricleLining.nii.gz "
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -equal 52 -bin -euc -uthr 0 -abs \
                             ${PathScratch}/Temp1.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -equal 53 -bin -euc -uthr 0 -abs \
                             -add ${PathScratch}/Temp1.nii.gz -uthr 5 -bin ${PathScratch}/PotentialInterVentr.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/VentricleLining.nii.gz -dil 1 ${PathScratch}/ExpandedVentrLin.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -thr 49.5 -uthr 53.5 -bin \
                             -sub ${PathScratch}/ExpandedVentrLin.nii.gz -thr 0 -bin ${PathScratch}/PotentialCP.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Segmentation_${ID}.nii.gz -tp 4 -thr 0.5 -bin \
                             -sub ${PathScratch}/VentricleLining* -thr 0 ${PathScratch}/SegDGM.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -equal 87 -mul -1 \
                             -add ${PathScratch}/PotentialInterVentr.nii.gz -sub ${PathScratch}/SegDGM.nii.gz -thr 0 \
                             ${PathScratch}/PotentialSP3.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/PotentialSP3.nii.gz -add ${PathScratch}/PotentialCP.nii.gz \
                             ${PathScratch}/PotentialSPCP.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/ICBM_ICSF* -thr 0.3 -bin -mul ${PathScratch}/PotentialSPCP.nii.gz \
                             -add ${PathScratch}/PotentialSP3.nii.gz -thr 0.2 -bin ${PathScratch}/PotentialSPCP2.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 83.5 -uthr 84.5 -bin -dil 5 \
                             ${PathScratch}/WMDil.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 91.5 -uthr 92.5 -bin -dil 5 \
                             ${PathScratch}/WMDil2.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/PotentialSPCP2.nii.gz -sub ${PathScratch}/WMDil.nii.gz \
                             -sub ${PathScratch}/WMDil2.nii.gz -thr 0 ${PathScratch}/PotentialSPCP3.nii.gz "
  echo "${PathSeg}/seg_maths ${PathScratch}/PrimaryLesions_* -sub ${PathScratch}/PotentialSPCP3.nii.gz -thr 0 \
                             ${PathScratch}/PrimarySPCP_${ID}_${OptTxt}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/SecondaryLesions_* -sub ${PathScratch}/PotentialSPCP3.nii.gz -thr 0 \
                             ${PathScratch}/SecondarySPCP_${ID}_${OptTxt}.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/PrimarySPCP*${OptTxt}* -merge 1 4 ${PathScratch}/SecondarySPCP_*${OptTxt}* \
                             -tmax ${PathScratch}/MergedLesion_${ID}_SPCP_${OptTxt}.nii.gz"
  # Changing initial PathResults to PathScratch, since that is where the previous lines save the images.
  echo "${PathSeg}/seg_maths ${PathScratch}/MergedLesion_${ID}_SPCP_${OptTxt}.nii.gz \
                             -sub ${PathScratch}/${ID}_Artefacts.nii.gz -thr 0 \
                             ${PathResults}/MergedLesion_${ID}_SPCP_${OptTxt}.nii.gz"

  echo "echo \"Correcting for third ventricle (refined).\""
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz \
                             -sub ${PathScratch}/GIF_Parcellation_${ID}.nii.gz ${PathScratch}/Artefacts_${ID}.nii.gz"
} >> "$NameScript"
for ((i=0;i<${#ListCorr[@]};i++))
do
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -equal ${ListCorr[i]} -bin \
                             -add ${PathScratch}/Artefacts_${ID}.nii.gz " >> "$NameScript"
done
{
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 65.5 -uthr 67.5 \
                             ${PathScratch}/VentrLin.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -equal 87 -add ${PathScratch}/VentrLin.nii.gz \
                             ${PathScratch}/VentrLin.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -equal 47 -euc  -abs -uthr 5 -bin -mul \
                             ${PathScratch}/VentrLin.nii.gz ${PathScratch}/VentrLinSP.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -equal 52 -bin -euc  -abs \
                             ${PathScratch}//Ventr1.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -equal 53 -bin -euc -abs -uthr 5 \
                             -sub ${PathScratch}/Ventr1.nii.gz -thr -5 -uthr 5 -bin \
                             -mul ${PathScratch}/GIF_Parcellation_${ID}.nii.gz  -equal 52 -bin -euc -abs -uthr 5 \
                             -mul ${PathScratch}/VentrLin.nii.gz  -add ${PathScratch}/VentrLinSP.nii.gz \
                             ${PathScratch}/VentrLinSP.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/VentrLinSP.nii.gz -add ${PathScratch}/Artefacts_${ID}.nii.gz -mul -1 \
                             -add ${PathScratch}/MergedLesion_${ID}_SPCP_${OptTxt}.nii.gz -thr 0 \
                             ${PathScratch}/MergedLesion_${ID}_${OptTxt}_corr.nii.gz"
  echo "echo \"\""
  echo "echo \"****************************************\""
  echo "echo \"Running second Seg_Analysis.\""
  echo "${PathSeg}/Seg_Analysis -LesWMI ${OptWMI} ${OptInfarcts} \
                                -inLesCorr ${PathScratch}/MergedLesion_${ID}_${OptTxt}_corr.nii.gz \
                                -inTxt2 ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.txt \
                                        ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.nii.gz \
                                -mask ${PathScratch}/GIF_B1_${ID}.nii.gz -Package 1 -SegType 1 -WeightedSeg 3 3 1 \
                                -connect -correct -inModa ${#arrayModNumber[@]} ${arrayModNumber[*]} \
                                -inRuleTxt ${RuleFileName} -WMCard 1 \
                                -inPriorsICSF ${PathScratch}/ICBM_ICSF_${ID}.nii.gz \
                                -inPriorsDGM ${PathScratch}/ICBM_DGM_${ID}.nii.gz \
                                -inPriorsCGM ${PathScratch}/ICBM_CGM_${ID}.nii.gz \
                                -inPriorsECSF ${PathScratch}/ICBM_ECSF_${ID}.nii.gz -TO 1 -juxtaCorr 1 -SP ${OptSP} \
                                -LevelCorrection ${OptCL} -inArtefact ${PathScratch}/${ID}_Artefacts.nii.gz \
                                ${ChangePathString} -ParcellationIn ${PathScratch}/GIF_Parcellation_${ID}.nii.gz \
                                -typeVentrSeg 1 -outWM 1 -outConnect 1 -Neigh 6"
  echo "echo \"****************************************\""
  echo "echo \"\""
#  echo "rm ${PathScratch}/LesionWeigh* ${PathScratch}/Binary* ${PathScratch}/WMDil* ${PathScratch}/WMCard* \
#           ${PathScratch}/LesionInit* ${PathScratch}/DataR* ${PathScratch}/DataT* ${PathScratch}/Summ* \
#           ${PathScratch}/LesSegHard* ${PathScratch}/Check* ${PathScratch}/BinaryNIV*"
} >> "$NameScript"

if ((flag_corrDGM==1))
then
  echo "echo \"Correcting deep grey matter.\"" >> "$NameScript"
  Array=(24   31  32  56  57  58  59  60  61  76  77  37  38)
  # Get segmentation of DGM from GIF
  if [ ! -f "${PathScratch}"/"${ID}"_DGM.nii.gz ]
  then
    if ((${#Array[@]}>0))
    then
      stringAddition="${PathScratch}/${ID}_DGMConstruction_0.nii.gz "
      for ((k=0;k<${#Array[@]};k++))
      do
        Value=${Array[k]}
        echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -equal ${Value} \
                                   -bin ${PathScratch}/${ID}_DGMConstruction_${k}.nii.gz " >> "$NameScript"
        stringAddition="${stringAddition} -add ${PathScratch}/${ID}_DGMConstruction_${k}.nii.gz "
      done
      echo "${PathSeg}/seg_maths ${stringAddition} -bin -odt char ${PathScratch}/${ID}_DGM.nii.gz " >> "$NameScript"
      echo "rm ${PathScratch}/*DGMConstruction* " >> "$NameScript"
    fi
  fi
  WMminIn_files=("${PathScratch}"/WMminIn*)
  WMminIn_file=${WMminIn_files[0]}
  if [ ! -f "$WMminIn_file" ]
  then
    {
      echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 81.5 -uthr 83.5 \
                                 ${PathScratch}/Insula_${ID}.nii.gz"
      echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 89.5 -uthr 91.5 \
                                 -add ${PathScratch}/Insula_${ID}.nii.gz -bin  ${PathScratch}/Insula_${ID}.nii.gz"
      echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 95.5 -uthr 97.5 \
                                 -add ${PathScratch}/Insula_${ID}.nii.gz -bin  ${PathScratch}/Insula_${ID}.nii.gz "
      echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 79 -uthr 98 -bin \
                                 -sub ${PathScratch}/Insula_${ID}.nii.gz ${PathScratch}/WMminIn_${ID}.nii.gz"
    } >> "$NameScript"
  fi
  {
    echo "${PathSeg}/seg_maths ${PathScratch}/GIF_Parcellation_${ID}.nii.gz -thr 23 -uthr 45 -bin \
                               ${PathScratch}/InfraDGM_${ID}.nii.gz"
    echo "${PathSeg}/seg_maths ${PathScratch}/${ID}_DGM* -add ${PathScratch}/Infra* -add ${PathScratch}/Insula* -bin \
                               -dil 1 -sub ${PathScratch}/WMminIn_${ID}.nii.gz -thr 0 \
                               ${PathScratch}/Correction_${ID}.nii.gz"
    echo "${PathSeg}/seg_maths ${PathScratch}/LesionMahal* -tp 2 -uthr 4 -bin -mul ${PathScratch}/Corr*Mer* \
                               -mul ${PathScratch}/Correction_${ID}.nii.gz -mul -1 -add ${PathScratch}/Corr*Mer* -thr 0 \
                               ${PathScratch}/Lesion_${ID}_corr.nii.gz"
    echo "echo \"\""
    echo "echo \"****************************************\""
    echo "echo \"Running third Seg_Analysis (if flag_corrDGM==1).\""
    echo "${PathSeg}/Seg_Analysis -LesWMI ${OptWMI}  -inLesCorr ${PathScratch}/Lesion_${ID}_corr.nii.gz \
                                  -inTxt2 ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.txt \
                                          ${PathScratch}/${ModalitiesTot}_BiASM_${ID}_${Opt}.nii.gz \
                                  -mask ${PathScratch}/GIF_B1_${ID}.nii.gz -Package 1 -SegType 1 -WeightedSeg 3 3 1 \
                                  -connect -correct -inModa 2 1 3 -inRuleTxt ${RuleFileName} -WMCard 1 \
                                  -inPriorsICSF ${PathScratch}/ICBM_ICSF_${ID}.nii.gz \
                                  -inPriorsDGM ${PathScratch}/ICBM_DGM_${ID}.nii.gz \
                                  -inPriorsCGM ${PathScratch}/ICBM_CGM_${ID}.nii.gz \
                                  -inPriorsECSF ${PathScratch}/ICBM_ECSF_${ID}.nii.gz -TO 1 -juxtaCorr 1 -SP ${OptSP} \
                                  -LevelCorrection ${OptCL} -inArtefact ${PathScratch}/Artefacts_${ID}.nii.gz \
                                  ${ChangePathString} -ParcellationIn ${PathScratch}/GIF_Parcellation_${ID}.nii.gz \
                                  -typeVentrSeg 1 -outWM 1 -outConnect 1 -Neigh 6"
    echo "echo \"****************************************\""
    echo "echo \"\""
  } >> "$NameScript"

fi

{
#  echo "rm ${PathScratch}/LesionWeigh* ${PathScratch}/Binary* ${PathScratch}/WMDil* ${PathScratch}/WMCard* \
#           ${PathScratch}/ICBM* ${PathScratch}/LesionInit* ${PathScratch}/DataR* ${PathScratch}/DataT* \
#           ${PathScratch}/Summ* ${PathScratch}/LesSegHard* ${PathScratch}/Check* ${PathScratch}/BinaryNIV*"
  echo "cp ${PathScratch}/*Co* ${PathResults}/."
#  echo "cp ${PathScratch}/*Co*.txt ${PathResults}/."
  echo "cp ${PathScratch}/LesionMahal* ${PathResults}/."
  echo "cp ${PathScratch}/Txt* ${PathResults}/."
  echo "cp ${PathScratch}/Out* ${PathResults}/."
  echo "cp ${PathScratch}/Autho* ${PathResults}/."
  echo "cp ${PathScratch}/*Infar* ${PathResults}/."
  echo "cp ${PathScratch}/*Artefacts.nii.gz ${PathResults}/."

#  echo "function finish { rm -rf ${PathScratch} ; }"
#  echo "trap finish EXIT ERR "
#  echo "rm -rf ${PathScratch}"
} >> "$NameScript"

echo "Running $NameScript."
bash "$NameScript"
