# GIF and BaMoS scripts

These scripts were originally written for the RISAPS project to run on the AI Centre cluster at the BMEIS. They ran in a
Docker container that included compiled versions of GIF and BaMoS, along with their dependencies.

You will need to update some of the fixed paths in the script to match your project.

## Installing GIF and BaMoS

See [docker](../docker) for scripts that compile the necessary component. You can replicate these steps in a local 
environment if you are working without Docker.

## Pipeline

* `submit` scripts
  * Create runAI jobs for each subject using run scripts
* `run` scripts are launched within the RunAI job, or can be used as the entrypoint outside RunAI / Docker
  * Check inputs.
  * Run GIF, BaMoS, and BaMoS post-processing scripts.
  * Log run events and record timing.
* [GIF](GIF.md)
  * `seg_gif` produces probabilistic segmentations of major tissue classes and discrete segmentations of smaller structures.
  * Also registers ICBM tissue priors to the subject space.
  * Results are copied by BaMoS and used in various steps.
* [BaMoS](BaMoS.md)
  * `BaMoS_RISAPS.sh` generates a run script for each subject.
    * A great many outputs and working files are saved and I do not know what they all do.
  * `correction_lesions.py`
    * Removes detected WMH lesions that are deemed to be improbable.
    * Produces `CorrectLesion_<subject>.nii.gz`
  * `LaplaceLobesScript.sh`
    * Creates a discrete segmentation from GIF's probabilistic segmentation: `<subject>_Seg1.nii.gz`
    * Divides white matter into layers based on proximity to ventricles: `Layers_<subject>.nii.gz`
    * Divides brain into 10 lobes: `Lobes_<subject>.nii.gz`
* Post-processing
  * `check_images.m`
    * Generates PNG images for visual checking of segmentation results.
  * `get_stats.m`
    * Computes total intracranial volume from GIF
    * Computes total WMH volume
    * Saves `tissue_lesion_stats.csv` in main BaMoS output directory
  * `get_stats_full.m`
    * Computes total intracranial volume from GIF
    * Computes volumes for the major tissue classes from GIF
    * Computes WMH volume for every lobe and layer (see BaMoS bullseye paper)
    * Computes number of discrete WMH lesions per lobe and layer, proportionally and absolutely (winner-takes-all)
    * Saves `tissue_lesion_stats_full.csv` in main BaMoS output directory

## Code and data sources

The BaMoS scripts were adapted from here: https://github.com/csudre/BaMoS

For details of the versions of the source code compiled in the Docker image, see [docker](../docker).
