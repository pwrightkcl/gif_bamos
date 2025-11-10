"""Read selected tags from the first DICOM file in each subdirectory and save as CSV and parquet.

Saves the index dataframe as parquet and CSV.
Specify dicom_tags to retrieve using keywords, e.g. Series Description (0008,103E) is 'SeriesDescription'.
https://dicom.innolitics.com/ciods/mr-image/general-series/0008103e
Requires pyarrow to save parquet files.
"""

from pathlib import Path
import csv

import pandas as pd
import pydicom
import timeit


root_dir = Path('/nfs/project/RISAPS/')
dicom_dir = root_dir / 'sourcedata/dicom'
di_out = root_dir / 'metadata' / 'dicom_index'
fields = ['PatientSex', 'EthnicGroup',
          'StudyDate', 'StudyTime', 'AccessionNumber', 'StudyDescription', 'StudyInstanceUID', 'StudyID',
          'PatientAge', 'PatientSize', 'PatientWeight', 'MedicalAlerts', 'Allergies', 'Occupation', 'SmokingStatus',
          'AdditionalPatientHistory', 'PregnancyStatus', 'PatientState',
          'SeriesDate', 'SeriesTime', 'Modality', 'SeriesDescription', 'BodyPartExamined', 'ProtocolName',
          'PatientPosition', 'SeriesInstanceUID', 'SeriesNumber',
          'Manufacturer', 'InstitutionName', 'InstitutionAddress', 'StationName', 'InstitutionalDepartmentName',
          'ManufacturerModelName', 'DeviceSerialNumber',
          'SliceThickness', 'PixelSpacing', 'Rows', 'Columns',
          'ContrastBolusAgent', 'ContrastBolusRoute',
          'ImageType', 'PatientOrientation', 'ImagesInAcquisition',
          'ScanOptions', 'KVP', 'DataCollectionDiameter', 'ReconstructionDiameter',
          'DistanceSourceToDetector', 'DistanceSourceToPatient', 'GantryDetectorTilt', 'XRayTubeCurrent',
          'ExposureTime', 'SingleCollimationWidth', 'TotalCollimationWidth', 'SamplesPerPixel',
          'PhotometricInterpretation', 'RescaleIntercept', 'RescaleSlope', 'RescaleType',
          'ScanningSequence', 'SequenceVariant', 'MRAcquisitionType', 'SequenceName',
          'AngioFlag', 'RepetitionTime', 'EchoTime', 'InversionTime', 'NumberOfAverages', 'ImagingFrequency',
          'ImagedNucleus', 'EchoNumbers', 'MagneticFieldStrength', 'SpacingBetweenSlices', 'NumberOfPhaseEncodingSteps',
          'EchoTrainLength', 'PercentSampling', 'PercentPhaseFieldOfView', 'PixelBandwidth', 'ReceiveCoilName',
          'TransmitCoilName', 'AcquisitionMatrix', 'InPlanePhaseEncodingDirection', 'FlipAngle',
          'VariableFlipAngleFlag',
          'dBdt', 'B1rms',
          'DiffusionDirectionality', 'DiffusionBValue',
          'FrameType', 'AcquisitionContrast',
          'ASLTechniqueDescription'
          ]

metadata = []
count_all = 0
count_dcm = 0
tic = timeit.default_timer()
print(f'Constructing DICOM index from {dicom_dir}')
spinner = ['|', '/', '-', '\\']
for subdirectory in dicom_dir.glob('**/'):
    print(f'\r{spinner[count_dcm%4]}{spinner[count_all%4]}', end='')
    count_all += 1
    dcm_files = list(subdirectory.glob('*.DCM'))
    if len(dcm_files) == 0:
        continue
    count_dcm += 1

    # Load the first .dcm file in the directory
    d = pydicom.dcmread(dcm_files[0])

    # Read selected fields into dictionary
    this_data = {'dcm_file': str(dcm_files[0])}

    for field in fields:
        this_data[field] = d[field].value if field in d else None
        # Try to handle MultiValue because these cause errors saving as parquet.
        if field in ['ImageType', 'PatientOrientation']:
            # I hope other tags will be like Image Type and consistently lists.
            this_data[field] = list(this_data[field])
        elif type(this_data[field]) == pydicom.multival.MultiValue:
            if field in ['SeriesDescription', 'ScanningSequence', 'ScanOptions', 'SequenceVariant']:
                # Series Description is very rarely multivalue and usually string.
                # Scanning Sequence is usually a string, but sometimes a list of strings.
                this_data[field] = ' '.join(this_data[field])
            else:
                # If in doubt, make it a string
                this_data[field] = str(this_data[field])

    metadata.append(this_data)

print('\r', end='')
toc = timeit.default_timer()
run_time = toc - tic
print(f'Indexed {count_all} directories, finding .dcm files in {count_dcm}, giving a final index of {len(metadata)} entries in {run_time:.2f} seconds.')
print('Converting to dataframe')
dicom_index = pd.DataFrame.from_dict(metadata)
print('Saving as CSV')
dicom_index.to_csv(di_out.with_suffix('.csv'), index=False, quoting=csv.QUOTE_NONNUMERIC)
print('Saving as parquet')
try:
    dicom_index.to_parquet(di_out.with_suffix('.parquet'))
except Exception as e:
    print("Could not save as parquet. Saving as pickle. It's probably a data type pyarrow doesn't like.")
    dicom_index.to_pickle(str(di_out.with_suffix('.pickle')))
    print("Here's the error message:")
    print(repr(e))
print('Done\n')
