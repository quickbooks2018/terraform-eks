#!/bin/bash

if [ ! -f ./RDS.env ]; then
  echo "Could not find ENV variables file for RDS. The file is missing: ./RDS.env"
  exit 1
fi

echo "First, deleting the old secret: rds-creds"
kubectl delete secret rds-creds || true

echo "Found RDS.env file, creating kubernetes secret: rds-creds"

source ./RDS.env

kubectl create namespace rds

kubectl get ns

# If you want to create remove --dry-run

kubectl -n rds create secret generic rds-creds \
  --from-literal=RDS_ENDPOINT=${RDS_ENDPOINT}  \
  --from-literal=DB_USERNAME=${DB_USERNAME} \
  --from-literal=DB_PASSWORD=${DB_PASSWORD}  \
  --output json