# GIF and BaMos

This repo contains scripts that were used to run GIF and BaMoS for the RISAPS project. They can be adapted for your 
project but will require a detailed readthrough.

## Pipeline overview

* **GIF** (Geodesic Information Flows) is used to segment brain images into different tissue types.
* **BaMoS** (Bayesian Model Selection) is used to segment white matter hyperintensities.
  * **Laplace Lobes** is used to define regions for describing WMH distribution.
  * **Correction script** is used to trim unlikely WMH labels.
* **Post-processing scripts** are used to tabulate volumes.
  * Manual masks are applied at this stage to exclude false positives from infarcts. 

To run this code on the KCL BMEIS cluster, run the relevant `submit` script (for GIF and BaMoS or just BaMoS). This will
submit one job to the cluster per subject and run the corresponding `run` script. The `run` script parses the input 
filenames, creates output directories, and keeps track of the timing of the GIF and BaMoS steps.

To create a RISAPS Docker image to run this code on the KCL BMEIS cluster, see [docker](docker).

For details of the GIF and BaMoS scripts, see [scripts](scripts).
