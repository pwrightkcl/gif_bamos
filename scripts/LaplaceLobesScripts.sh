#!/bin/bash

PathSeg=/usr/local/bin

# First get all names
if [ $# -lt 5 ]
then
echo ""
echo "******************************"
echo "Usage: sh ~/Scripts/LaplaceLobesScripts.sh Path ID PathGIF PathLesion PathT1"
echo ""
echo "Path:       path to BaMoS output."
echo "ID:         subject identifier for filename prefix,"
echo "            should match that used for BaMoS."
echo "PathGIF:    path to GIF output."
echo "PathLesion: path to corrected lesion image from BaMoS."
echo "PathT1:     path to T1 image."
echo "******************************"
echo ""
exit
fi

Path=${1}
ID=${2}
PN=${ID}
PathGIF=${3}
Lesion=${4}
T1=${5}

FrontalArray=(105 106 147 148 137 138 179 180 191 192 143 144 163 164 165 166 205 206 125 126 141 142 187 188 153 154
              183 184 151 152 193 194 119 120 113 114 121 122)
ParietalArray=(169 170 175 176 195 196 199 200 107 108 177 178 149 150)
OccipitalArray=(115 116 109 110 135 136 161 162 197 198 129 130 145 146 157 158)
TemporalArray=(117 118 123 124 171 172 133 134 155 156 201 202 203 204 181 182 185 186 207 208)
BGArray=(16 24 31 32 33 37 38 56 57 58 59 60 61 76 77)
VentrArray=(5 16 12 47 50 51 52 53)
ITArray=(35 36 39 40 41 42 43 44 72 73 74)

if [ ! -d "$Path" ]
then
  mkdir -p "$Path"
fi

NameScript=${Path}/${ID}_scriptLayers.sh
echo "Constructing local script \"${NameScript}\"."
echo "#!/bin/bash" > "${NameScript}"
chmod +x "$NameScript"

ValueLesion=("${Lesion}"*)

# Get segmentation from GIF
echo "echo \"Constructing infratentorial mask.\"" >> "$NameScript"
stringAddition="${Path}/${ID}_ITConstruction_0.nii.gz "
for ((k=0;k<${#ITArray[@]};k++))
do
  Value=${ITArray[k]}
  echo "${PathSeg}/seg_maths ${PathGIF}/*Parcellation.nii.gz -equal $Value -bin ${Path}/${ID}_ITConstruction_${k}.nii.gz " >> "$NameScript"
  stringAddition="${stringAddition} -add ${Path}/${ID}_ITConstruction_${k}.nii.gz "
done
echo "${PathSeg}/seg_maths ${stringAddition} -bin -odt char ${Path}/${ID}_Infratentorial.nii.gz " >> "$NameScript"
echo "rm ${Path}/*ITConstruction* " >> "$NameScript"

LaplaceWMDGMLes_files=("${Path}"/Laplace*WMDGMLes*_4_"${ID}"_*)
LaplaceWMDGMLes_file=${LaplaceWMDGMLes_files[0]}
if [ ! -f "$LaplaceWMDGMLes_file" ]
then
  {
    echo "echo \"Preparing masks for La Place analysis.\""
    echo "${PathSeg}/seg_maths ${PathGIF}/*Segmentation* -tpmax ${Path}/${ID}_Seg1.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Seg1.nii.gz -thr 0.5 -uthr 1.5 ${Path}/${ID}_CSF_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Seg1.nii.gz -thr 1.5 -uthr 2.5 ${Path}/${ID}_CGM_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Seg1.nii.gz -thr 2.5 -uthr 3.5 ${Path}/${ID}_WM_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Seg1.nii.gz -thr 3.5 -uthr 4.5 ${Path}/${ID}_DGM_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Seg1.nii.gz -thr 4.5 -uthr 5.5 ${Path}/${ID}_Brainstem_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_DGM_bin.nii.gz -add ${Path}/${ID}_WM_bin.nii.gz ${Path}/${ID}_WMDGM_bin.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_WMDGM_bin.nii.gz -smo 1 ${Path}/${ID}_WMDGM_ext.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_CGM_bin.nii.gz -smo 1 ${Path}/${ID}_CGM_ext.nii.gz"
    # Creation of Ventr/Sim segmentation
    echo "${PathSeg}/seg_maths ${PathGIF}/*Parcellation** -thr 49.5 -uthr 53.5 -bin ${Path}/${ID}_Ventr2.nii.gz"
    echo "${PathSeg}/seg_maths ${PathGIF}/*Parcellation* -thr 4.5 -uthr 16.5 -bin ${Path}/${ID}_Ventr3.nii.gz"
    echo "${PathSeg}/seg_maths ${Path}/${ID}_Ventr2.nii.gz -add ${Path}/${ID}_Ventr3.nii.gz -sub ${ValueLesion[0]} \
                               -thr 0.5 ${Path}/${ID}_VentrTot.nii.gz"
    # Creation of Parenchymal filled
    echo "${PathSeg}/seg_maths ${Path}/${ID}_WMDGM_bin.nii.gz -add ${ValueLesion[0]} \
                               -add ${Path}/${ID}_Brainstem_bin.nii.gz -add ${Path}/${ID}_VentrTot.nii.gz -bin \
                               -lconcomp ${Path}/${ID}_WMDGMLes.nii.gz "
    echo "echo \"\""
    echo "echo \"****************************************\""
    echo "echo \"Running Seg_Analysis -LapIO.\""
    echo "${PathSeg}/Seg_Analysis -LapIO ${Path}/${ID}_VentrTot.nii.gz ${Path}/${ID}_WMDGMLes.nii.gz  -numbLaminae 1  4 \
                                  -nameLap WMDGMLes"
    echo "echo \"****************************************\""
    echo "echo \"\""
    echo "echo \"Copying LaplaceLayers to Layers.\""
    echo "cp ${Path}/LaplaceLayers*${PN}* ${Path}/Layers_${PN}.nii.gz"
  } >> "$NameScript"
else
  echo "echo \"Found existing output so skipping Seg_Analysis -LapIO.\"" >> "$NameScript"
fi
echo "rm ${Path}/${ID}*bin.nii.gz ${Path}/${ID}*ext.nii.gz ${Path}/${ID}*Ventr*.nii.gz" >> "$NameScript"

echo "echo \"Copying files to scratch directory.\"" >> "$NameScript"
PathScratch=/tmp/${PN}_GenericLobes
{
  echo "mkdir -p $PathScratch"
  echo "${PathSeg}/seg_maths ${T1} -odt float ${PathScratch}/T1_${PN}.nii.gz "
  echo "cp ${Path}/Lap* ${PathScratch}/."
  echo "cp ${Path}/Brainmask/* ${PathScratch}/."
  echo "cp ${PathGIF}/* ${PathScratch}/."
  echo "cp ${PathScratch}/*NeuroMorph*Parcellation* ${PathScratch}/${PN}_Parcellation.nii.gz"
  echo "${PathSeg}/seg_maths ${PathScratch}/*TIV.nii.gz -thr 0.5 -bin -odt char ${PathScratch}/${PN}_GIF_B1.nii.gz"
} >> "$NameScript"

echo "echo \"Constructing frontal lobe mask.\"" >> "$NameScript"
stringAddition1="${PathScratch}/${PN}_FrontalConstruction_0.nii.gz "
stringAddition2="${PathScratch}/${PN}_FrontalConstruction_1.nii.gz "
for ((i=0;i<${#FrontalArray[@]};i++))
do
  Value=${FrontalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_FrontalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition1="${stringAddition1} -add ${PathScratch}/${PN}_FrontalConstruction_${i}.nii.gz "
  ((i++))
  Value=${FrontalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_FrontalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition2="${stringAddition2} -add ${PathScratch}/${PN}_FrontalConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition2} -bin -odt char ${PathScratch}/${PN}_FrontalLobeL.nii.gz "
  echo "${PathSeg}/seg_maths ${stringAddition1} -bin -odt char ${PathScratch}/${PN}_FrontalLobeR.nii.gz "
  echo "rm ${PathScratch}/*FrontalConstruction* "
  echo "cp ${PathScratch}/*FrontalLobe*.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing parietal lobe mask.\"" >> "$NameScript"
stringAddition1="${PathScratch}/${PN}_ParietalConstruction_0.nii.gz "
stringAddition2="${PathScratch}/${PN}_ParietalConstruction_1.nii.gz "
for ((i=0;i<${#ParietalArray[@]};i++))
do
  Value=${ParietalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_ParietalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition1="${stringAddition1} -add ${PathScratch}/${PN}_ParietalConstruction_${i}.nii.gz "
  ((i++))
  Value=${ParietalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_ParietalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition2="${stringAddition2} -add ${PathScratch}/${PN}_ParietalConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition2} -bin -odt char ${PathScratch}/${PN}_ParietalLobeL.nii.gz "
  echo "${PathSeg}/seg_maths ${stringAddition1} -bin -odt char ${PathScratch}/${PN}_ParietalLobeR.nii.gz "
  echo "rm ${PathScratch}/*ParietalConstruction* "
  echo "cp ${PathScratch}/*ParietalLobe*.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing occipital lobe mask.\"" >> "$NameScript"
stringAddition1="${PathScratch}/${PN}_OccipitalConstruction_0.nii.gz "
stringAddition2="${PathScratch}/${PN}_OccipitalConstruction_1.nii.gz "
for ((i=0;i<${#OccipitalArray[@]};i++))
do
  Value=${OccipitalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_OccipitalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition1="${stringAddition1} -add ${PathScratch}/${PN}_OccipitalConstruction_${i}.nii.gz "

  ((i++))
  Value=${OccipitalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_OccipitalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition2="${stringAddition2} -add ${PathScratch}/${PN}_OccipitalConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition2} -bin -odt char ${PathScratch}/${PN}_OccipitalLobeL.nii.gz "
  echo "${PathSeg}/seg_maths ${stringAddition1} -bin -odt char ${PathScratch}/${PN}_OccipitalLobeR.nii.gz "
  echo "rm ${PathScratch}/*OccipitalConstruction* "
  echo "cp ${PathScratch}/*OccipitalLobe*.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing temporal lobe mask.\"" >> "$NameScript"
stringAddition1="${PathScratch}/${PN}_TemporalConstruction_0.nii.gz "
stringAddition2="${PathScratch}/${PN}_TemporalConstruction_1.nii.gz "
for ((i=0;i<${#TemporalArray[@]};i++))
do
  Value=${TemporalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_TemporalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition1="${stringAddition1} -add ${PathScratch}/${PN}_TemporalConstruction_${i}.nii.gz "

  ((i++))
  Value=${TemporalArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_TemporalConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition2="${stringAddition2} -add ${PathScratch}/${PN}_TemporalConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition2} -bin -odt char ${PathScratch}/${PN}_TemporalLobeL.nii.gz "
  echo "${PathSeg}/seg_maths ${stringAddition1} -bin -odt char ${PathScratch}/${PN}_TemporalLobeR.nii.gz "
  echo "rm ${PathScratch}/*TemporalConstruction* "
  echo "cp ${PathScratch}/*TemporalLobe*.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing basal ganglia mask.\"" >> "$NameScript"
stringAddition="${PathScratch}/${PN}_BGConstruction_0.nii.gz "
for ((i=0;i<${#BGArray[@]};i++))
do
  Value=${BGArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin -ero 1 -lconcomp -dil 1 \
                             ${PathScratch}/${PN}_BGConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition="${stringAddition} -add ${PathScratch}/${PN}_BGConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition} -bin -dil 4 -fill -ero 4 -odt char \
                             ${PathScratch}/${PN}_BasalGanglia.nii.gz "
  echo "rm ${PathScratch}/*BGConstruction* "
  echo "cp ${PathScratch}/*BasalGanglia.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing infratentorial mask.\"" >> "$NameScript"
stringAddition="${PathScratch}/${PN}_ITConstruction_0.nii.gz "
for ((i=0;i<${#ITArray[@]};i++))
do
  Value=${ITArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value  -bin \
                             ${PathScratch}/${PN}_ITConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition="${stringAddition} -add ${PathScratch}/${PN}_ITConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition} -bin -odt char ${PathScratch}/${PN}_Infratentorial.nii.gz "
  echo "rm ${PathScratch}/*ITConstruction* "
  echo "cp ${PathScratch}/*Infratentorial.nii.gz ${Path}/."
} >> "$NameScript"

echo "echo \"Constructing ventricle mask.\"" >> "$NameScript"
stringAddition="${PathScratch}/${PN}_VentrConstruction_0.nii.gz "
for ((i=0;i<${#VentrArray[@]};i++))
do
  Value=${VentrArray[i]}
  echo "${PathSeg}/seg_maths ${PathScratch}/${PN}_Parcellation.nii.gz -equal $Value -bin \
                             ${PathScratch}/${PN}_VentrConstruction_${i}.nii.gz " >> "$NameScript"
  stringAddition="${stringAddition} -add ${PathScratch}/${PN}_VentrConstruction_${i}.nii.gz "
done
{
  echo "${PathSeg}/seg_maths ${stringAddition} -bin -odt char ${PathScratch}/${PN}_Ventricles.nii.gz "
  echo "rm ${PathScratch}/*VentrConstruction* "
  echo "cp ${PathScratch}/*Ventricle*.nii.gz ${Path}/."
} >> "$NameScript"

LaplaceSolFile=${Path}/LaplaceSol_${ID}_VentrTot.nii.gz
{
  echo "${PathSeg}/seg_maths ${PathScratch}/T1_${PN}.nii.gz -odt float ${PathScratch}/T1_${PN}.nii.gz"
  echo "echo \"\""
  echo "echo \"****************************************\""
  echo "echo \"Running Seg_Analysis -LaplaceNormSol.\""
  echo "${PathSeg}/Seg_Analysis -LaplaceNormSol ${LaplaceSolFile} -inLobes 10 \
                                ${PathScratch}/${PN}_FrontalLobeL.nii.gz ${PathScratch}/${PN}_FrontalLobeR.nii.gz \
                                ${PathScratch}/${PN}_ParietalLobeL.nii.gz ${PathScratch}/${PN}_ParietalLobeR.nii.gz \
                                ${PathScratch}/${PN}_OccipitalLobeL.nii.gz ${PathScratch}/${PN}_OccipitalLobeR.nii.gz \
                                ${PathScratch}/${PN}_TemporalLobeL.nii.gz ${PathScratch}/${PN}_TemporalLobeR.nii.gz \
                                ${PathScratch}/${PN}_BasalGanglia.nii.gz ${PathScratch}/${PN}_Infratentorial.nii.gz \
                                -mask ${PathScratch}/${PN}_GIF_B1.nii.gz \
                                -inLesCorr ${PathScratch}/T1_${PN}.nii.gz \
                                -inVentricleSeg ${PathScratch}/${PN}_Ventricles.nii.gz \
                                -ParcellationIn ${PathScratch}/${PN}_Parcellation.nii.gz"
  echo "echo \"****************************************\""
  echo "echo \"\""

  echo "echo \"Clean up and finish.\""
  echo "echo \"Contents of scratch directory:\""
  echo "ls $PathScratch"
  echo "cp ${PathScratch}/DistanceChoice_T1_${PN}.nii.gz ${Path}/Lobes_${PN}.nii.gz"
  echo "rm -r ${PathScratch} "
  echo "echo \"Local script complete.\""
} >> "$NameScript"

####################

echo "Running local script."
bash "${NameScript}"
