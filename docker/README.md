# GIF & BaMoS docker image

## Base image
The base image is Ubuntu 22.04 LTS.

## NiftyReg
* Source: https://github.com/KCL-BMEIS/niftyreg
* Commit 6db8b16c17884a9b8859c980c4f1c408f62bd9ca
* Build version 76

## NiftySeg
* Source: https://github.com/KCL-BMEIS/NiftySeg
* Commit 16cf56313e3e28a8e47acfd02fff456784d99161
* Edits:
  * Option INSTALL_PRIORS OFF (will mount priors rather than building into image).

## GIF
* Online source: https://github.com/KCL-BMEIS/gif
* Commit: 9e194b52bbdac813c16d1bce4258c3ba0e7105d0
* BMEIS: /nfs/project/AMIGO/GIF
* NaN: compiled binary `seg_GIF` in /data/project/sib/code/derivatives/gif

## BaMoS
* Source: https://github.com/csudre/BaMoS
* Commit c43a7a2f59a47ffabac779debd2f23b4bf4b6f02
* Edits:
  * Option BUILD_ALL OFF.
  * Option INSTALL_NIFTYREG OFF.
  * Option INSTALL_PRIORS OFF (will mount priors rather than building into image).
  * Commented out two lines below `# Install scripts`.
  * Commented out lines seg-apps/Seg_Analysis.cpp and Seg_BiASM.cpp in referencing images in Carole's home space, assuming these were for debugging.
