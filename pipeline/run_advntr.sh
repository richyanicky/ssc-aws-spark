#!/bin/bash
set -x
#Input values
CRAMSLIST=$1
FAMID=$2
ENC_SSC_ACCESS_KEY=$3
ENC_SSC_SECRET_ACCESS_KEY=$4
#STARTCHR=${5:-1}
SSC_PARAMS=${5}
echo "[run_advntr.sh]: ${FAMID}: ${CRAMSLIST}"

die()
{
    BASE=$(basename "$0")
    echo "$BASE error: $1" >&2
    exit 1
}
#wget https://repo.anaconda.com/archive/Anaconda3-2019.03-Linux-x86_64.sh -O /tmp/anaconda3.sh

# Run the installer (installing without -p should automatically install into '/' (root dir)
#bash /tmp/anaconda3.sh -b -p /home/ec2-user/anaconda3
#rm /tmp/anaconda3.sh

### Run the conda init script to setup the shell
#echo ". /home/ec2-user/anaconda3/etc/profile.d/conda.sh" >> /home/ec2-user/.bashrc
#. /home/ec2-user/anaconda3/etc/profile.d/conda.sh
#source /home/ec2-user/.bashrc

# Create a base Python3 environment separate from the base env
#conda create -y --name python3

# +++++++++++++++++++++ END ANACONDA INSTALL ++++++++++++++++++++++


# ++++++++++++++ SETUP ENV +++++++++++++++

# Install necessary Python packages
# Note that 'source' is deprecated, so now we should be using 'conda' to activate/deactivate envs
#conda activate python3
#conda install -y -c conda-forge awscli 

# Setup the credentials for the AWS CLI
#aws configure set aws_access_key_id $1
#aws configure set aws_secret_access_key $2
# #############
DATADIR=/scratch # This is where we have all the EBS storage space mounted

# Set up
mkdir -p ${DATADIR}/${FAMID}/datafiles
mkdir -p ${DATADIR}/${FAMID}/results
mkdir -p ${DATADIR}/${FAMID}/tmp/


ls -la ${DATADIR}/${FAMID}/
ls -la ${DATADIR}/${FAMID}/results


rm ${DATADIR}/${FAMID}/results/*
rm ${DATADIR}/${FAMID}/datafiles/*
rm ${DATADIR}/${FAMID}/tmp/*

aws s3 cp s3://ssc-advntr-denovos/scripts/${SSC_PARAMS} ${DATADIR}/${FAMID}/${SSC_PARAMS} || die "Error copying ${SSC_PARAMS}"
source ${DATADIR}/${FAMID}/${SSC_PARAMS}
aws s3 cp s3://ssc-advntr-denovos/scripts/ssc_shared_params.sh ${DATADIR}/${FAMID}/ssc_shared_params.sh || die "Error copying ${SSC_PARAMS}"
source ${DATADIR}/${FAMID}/ssc_shared_params.sh
aws s3 cp s3://ssc-advntr-denovos/scripts/decrypt.py ${DATADIR}/${FAMID}/  || die "Error copying decrypt.py"
aws s3 cp s3://ssc-advntr-denovos/scripts/encrypt_code.txt ${DATADIR}/${FAMID}/  || die "Error copying encrypt_code.txt"


# Get encrypted SSC credentials
MESSAGE=$(cat ${DATADIR}/${FAMID}/encrypt_code.txt)
SSC_ACCESS_KEY=$(python3 ${DATADIR}/${FAMID}/decrypt.py ${MESSAGE} ${ENC_SSC_ACCESS_KEY})
SSC_SECRET_ACCESS_KEY=$(python3 ${DATADIR}/${FAMID}/decrypt.py ${MESSAGE} ${ENC_SSC_SECRET_ACCESS_KEY})

# Set up SSC profile
aws configure --profile ssc2 set aws_access_key_id $SSC_ACCESS_KEY
aws configure --profile ssc2 set aws_secret_access_key $SSC_SECRET_ACCESS_KEY
aws configure --profile ssc2 set region us-east-1

## First, download data files needed for GangSTR
# Ref genome from SSC
echo "[run_advntr.sh]: Downloading ref genome"
aws s3 --profile ssc2 cp ${REFFASTA} ${DATADIR}/${FAMID}/datafiles/ref.fa || die "Error copying GangSTR ref FASTA: ${REFFASTA}"
samtools faidx ${DATADIR}/${FAMID}/datafiles/ref.fa || die "Could not index ref fasta"

# BAM files from SSC
echo "[run_gangstr.sh]: Downloading CRAMs"
for CRAM in $(echo ${CRAMSLIST} | sed "s/(//g" | sed "s/)//g" | sed "s/;/ /g")
do
  aws s3 --profile ssc2 cp ${CRAM} ${DATADIR}/${FAMID}/datafiles/ || die "Could not copy ${CRAM}"
  aws s3 --profile ssc2 cp ${CRAM}.crai ${DATADIR}/${FAMID}/datafiles/ || die "Could not copy ${CRAM}.crai"
done

CRAMSINPUT=$(ls ${DATADIR}/${FAMID}/datafiles/*.cram | tr '\n' ',' | sed 's/,$//') # Get comma sep list of crams
echo "CRAM files list" ${CRAMSINPUT}


ARRA=(1 2)
for chrom in ${ARRA[@]};
do
# advntr reference regions
aws s3 cp s3://ssc-advntr-denovos/datafiles/GRCh38_VNTRs_chr${chrom}.db ${DATADIR}/${FAMID}/datafiles/GRCh38_VNTRs_chr${chrom}.db || die "Error copying adVNTR ref db:"

for cram in $(echo ${CRAMSINPUT} | sed "s/,/ /g");
do

    sampid=$(echo "$cram" | cut -d"/" -f5 | cut -d"." -f1)
    ### Second, run GangSTR
    paramsadv="genotype --alignment_file ${cram} --models ${DATADIR}/${FAMID}/datafiles/GRCh38_VNTRs_chr${chrom}.db -r ${DATADIR}/${FAMID}/datafiles/ref.fa --working_directory ${DATADIR}/${FAMID}/tmp --outfmt vcf  --outfile ${DATADIR}/${FAMID}/results/${FAMID}_chr${chrom}_${sampid}.vcf"
    
    cmd="advntr ${paramsadv} "
    
    cmd="${cmd} && aws s3 cp ${DATADIR}/${FAMID}/results/${FAMID}_chr${chrom}_${sampid}.vcf ${GANGSTRDIR}/ "

    echo $cmd 
done | xargs -n1 -I% -P5 sh -c "%"
done 

### Cleanup before moving on to next job
rm ${DATADIR}/${FAMID}/results/*
rm ${DATADIR}/${FAMID}/datafiles/*
rm ${DATADIR}/${FAMID}/tmp/*
exit 0
