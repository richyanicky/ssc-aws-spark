 #!/bin/bash python3
# Run this script on snorlax inside script dir
# Run command ./aws_job_run_gangstr_chrx.sh

#SSC_FILE='../files/SSC_phase1t_crams_input.tab'
SSC_FILE='../files/SSC_crams_input.test'
SSC_PARAMS='sscp1_params.sh'


#SSC_FILE='../files/SSC_crams_input2.test'
#SSC_PARAMS='sscp2_params.sh'

#SSC_FILE='../files/SSC_phase4_crams_input.tab'
#SSC_PARAMS='sscp4_params.sh'



# Upload Parameters
source ../ssc_shared_params.sh
source ../${SSC_PARAMS}
aws s3 cp ../ssc_shared_params.sh s3://ssc-advntr-denovos/scripts/ || echo "ssc_shared_params.sh upload to s3 failed"
aws s3 cp ../${SSC_PARAMS} s3://ssc-advntr-denovos/scripts/ || echo "${SSC_PARAMS} upload to s3 failed"

# Upload scripts
aws s3 cp ../pipeline/run_advntr.sh s3://ssc-advntr-denovos/scripts/ || echo "run_gangstr_chrx.sh upload to s3 failed"
aws s3 cp ../src/decrypt.py s3://ssc-advntr-denovos/scripts/ || echo "decrypt.py upload to s3 failed"
aws s3 cp ../files/encrypt_code.txt s3://ssc-advntr-denovos/scripts/encrypt_code.txt ||  echo "encrypt_code.txt upload to s3 failed"
aws s3 cp ../files/ssc_crams_sample_data.csv s3://ssc-advntr-denovos/scripts/ssc_crams_sample_data.csv ||  echo "ssc_crams_sample_data.csv upload to s3 failed"


SSC_ACCESS_KEY=$(cat ~/.aws/credentials | grep -A 2 ssc2 | grep id | cut -f 2 -d '=' | cut -f 2 -d' ' )
SSC_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep -A 2 ssc2 | grep secret | cut -f 2 -d '=' | cut -f 2 -d' ' )
MESSAGE=$(cat ../files/encrypt_code.txt)
ENC_SSC_ACCESS_KEY=$(python3 ../src/encrypt.py ${MESSAGE} ${SSC_ACCESS_KEY})
ENC_SSC_SECRET_ACCESS_KEY=$(python3 ../src/encrypt.py ${MESSAGE} ${SSC_SECRET_ACCESS_KEY})

# Read SSC family list
while read -r FAMID CRAMSLIST; do
  echo "Run advntr for ${FAMID} chrX"
  aws batch submit-job \
      --job-name ssc-${FAMID} \
      --job-queue ssc-denovo \
      --job-definition SSC-advntr:14 \
      --container-overrides 'command=["run_advntr.sh",'"${CRAMSLIST}"','"${FAMID}"','"${ENC_SSC_ACCESS_KEY}"','"${ENC_SSC_SECRET_ACCESS_KEY}"', '"${SSC_PARAMS}"'],environment=[{name="BATCH_FILE_TYPE",value="script"},{name="BATCH_FILE_S3_URL",value="s3://ssc-advntr-denovos/scripts/run_advntr.sh"}]'

done <${SSC_FILE}
