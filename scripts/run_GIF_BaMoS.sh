#!/bin/bash

SECONDS=0
if [ $# -lt 3 ]
then
	echo ""
	echo "*********************************"
	echo "Usage: $0 input_T1 input_FLAIR id"
	echo "*********************************"
	echo ""
	exit
fi

script_path=$(dirname "$0")
input_T1=$1
input_FLAIR=$2
id=$3

date
echo "Preparing to run GIF and BaMoS."
echo "T1 image: $input_T1"
echo "FLAIR image: $input_FLAIR"
echo "Subject ID: $id"

image_path=$(dirname "$input_T1")
GIF_results_path=${image_path/rawdata/derivatives\/GIF}
BaMoS_results_path=${image_path/rawdata/derivatives\/BaMoS}
if [ ! -d "$GIF_results_path" ]
then
  mkdir -p "$GIF_results_path"
fi
if [ ! -d "$BaMoS_results_path" ]
then
  mkdir -p "$BaMoS_results_path"
fi

GIF_log="${GIF_results_path}"/${id}_GIF.log
BaMoS_log="${BaMoS_results_path}"/${id}_BaMoS.log

echo ""
date
echo "Starting GIF."
tic_gif=$SECONDS
date > "$GIF_log"
database=/nfs/project/RISAPS/sourcedata/GIF_db/db/db.xml
seg_GIF -in "$input_T1" -db $database -v 1 -regNMI -out "$GIF_results_path" \
        -temper 0.05 -lncc_ker -4 -omp 8 -regBE 0.001 -regJL 0.00005 >> "$GIF_log" 2>&1
# Make total intracranial volume by excluding non-brain labels from parcellation
echo "Creating total intracranial volume image."
parcs=("${GIF_results_path}"/*NeuroMorph_Parcellation.nii.gz)
if (( ${#parcs[@]} > 1 ))
then
  printf "More than one GIF Parcellation found in %s.\nUsing first of the following:\n" "$GIF_results_path"
  echo "${parcs[@]}"
fi
parc=${parcs[0]}
tiv="${parc/NeuroMorph_Parcellation/TIV}"
seg_maths "$parc" -thr 3.5 -bin "$tiv"
echo "GIF complete."
{ echo "" ; date ; } >> "$GIF_log"
toc_gif=$SECONDS
echo ""

date
echo "Running BaMoS."
tic_bam=$SECONDS
date > "$BaMoS_log"
"$script_path"/BaMoS.sh "$id" "$input_FLAIR" "$input_T1" "$GIF_results_path" "$BaMoS_results_path" >> "$BaMoS_log" 2>&1
toc_bam=$SECONDS
echo "BaMoS complete."

echo ""
echo "Running BaMoS post-processing scripts."
tic_bampp=$SECONDS
lesion="$BaMoS_results_path"/Correct_WS3WT3WC1Lesion_${id}_corr.nii.gz
connect="$BaMoS_results_path"/Connect_WS3WT3WC1Lesion_${id}_corr.nii.gz
label="$BaMoS_results_path"/TxtLesion_WS3WT3WC1Lesion_${id}_corr.txt
parc="$BaMoS_results_path"/GIF_Parcellation_${id}.nii.gz

echo "Lesion correction."
{
  echo ""
  date
  echo "correction_lesions.py"
  python3 -u "$script_path"/correction_lesions.py -les "$lesion" -connect "$connect" -label "$label" -parc "$parc"\
                                               -corr choroid cortex sheet -id "$id"
} >> "$BaMoS_log" 2>&1
lesion_corrected="$BaMoS_results_path"/CorrectLesion_${id}.nii.gz

echo "La Place lobes."
laplace_dir="${BaMoS_results_path}"/Laplace
mkdir -p "$laplace_dir"
{
  echo ""
  date
  echo "LaplaceLobesScripts.sh"
  "$script_path"/LaplaceLobesScripts.sh "$laplace_dir" "$id" "$GIF_results_path" "$lesion_corrected" "$input_T1"
  echo ""
  date
} >> "$BaMoS_log" 2>&1
echo "BaMoS post-processing complete."
toc_bampp=$SECONDS

echo ""
t_gif=$((toc_gif - tic_gif))
h_gif=$((t_gif / 3600)); m_gif=$(( (t_gif % 3600) / 60 )); s_gif=$(( (t_gif % 3600) % 60 ))
printf 'GIF runtime: %02d:%02d:%02d\n' $h_gif $m_gif $s_gif
t_bam=$((toc_bam - tic_bam))
h_bam=$((t_bam / 3600)); m_bam=$(( (t_bam % 3600) / 60 )); s_bam=$(( (t_bam % 3600) % 60 ))
printf 'BaMoS runtime: %02d:%02d:%02d\n' $h_bam $m_bam $s_bam
t_bampp=$((toc_bampp - tic_bampp))
h_bampp=$((t_bampp / 3600)); m_bampp=$(( (t_bampp % 3600) / 60 )); s_bampp=$(( (t_bampp % 3600) % 60 ))
printf 'BaMoS post-proc runtime: %02d:%02d:%02d\n' $h_bampp $m_bampp $s_bampp
t_all=$SECONDS
h_all=$((t_all / 3600)); m_all=$(( (t_all % 3600) / 60 )); s_all=$(( (t_all % 3600) % 60 ))
printf 'Total runtime: %02d:%02d:%02d\n' $h_all $m_all $s_all
echo ""
date
echo "Script complete."
