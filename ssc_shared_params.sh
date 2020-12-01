#!/bin/bash

# Extra params
THREADS=4

# GangSTR params:
#Reference set of regions to genotype - Yes "chr" in hg38
REFBED=s3://gangstr-refs/hg38/hg38_ver16.bed.gz
REFFASTA=s3://sscwgs-hg38/documentation/GRCh38_full_analysis_set_plus_decoy_hla.fa

# Other params:
OTHERDIR=s3://ssc-advntr-denovos/other
