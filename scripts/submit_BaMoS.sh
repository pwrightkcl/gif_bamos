#!/bin/bash

input_dir=/nfs/project/RISAPS/rawdata

for subject_path in "$input_dir"/sub*
do
  subject=$(basename "$subject_path")
  image_dir="$subject_path"/ses-v3/anat
  input_T1s=("$image_dir"/*T1.nii.gz)
  input_FLAIRs=("$image_dir"/*FLAIR.nii.gz)
  if [ ${#input_T1s[@]} -eq 1 ] && [ ${#input_FLAIRs[@]} -eq 1 ]
  then
    input_T1=${input_T1s[0]}
    input_FLAIR=${input_FLAIRs[0]}
    if [ -f "$input_T1" ] && [ -f "$input_FLAIR" ]
    then
      runai submit risaps-bamos-"$subject" \
        -i aicregistry:5000/pwright:risaps0.4 \
        -v /nfs/project/RISAPS:/nfs/project/RISAPS \
        --run-as-user \
        --backoff-limit 0 \
        --gpu 0 \
        --cpu-limit 8 \
        --large-shm \
        --command -- \
          /nfs/project/RISAPS/code/scripts/run_BaMoS.sh "$input_T1" "$input_FLAIR" "$subject"
    else
      echo "Did not find T1 and FLAIR for $subject. Skipping."
    fi
  else
    echo "Multiple possible input images for $subject. Please figure out which one to use."
    echo "*T1.nii.gz: ${#input_T1s[@]} file(s)."
    echo "*FLAIR.nii.gz: ${#input_FLAIRs[@]} file(s)."
  fi
  echo ""
done
