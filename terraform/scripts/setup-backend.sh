#!/bin/bash
set -e

RESOURCE_GROUP="rg-aksdemo-tfstate"
STORAGE_ACCOUNT="staksdemostate"
CONTAINER="tfstate"
LOCATION="germanywestcentral"

echo "Creating resource group for Terraform state..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

echo "Creating storage account..."
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Creating blob container..."
az storage container create \
  --name $CONTAINER \
  --account-name $STORAGE_ACCOUNT

echo "Enabling versioning for state history..."
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true

echo ""
echo "Backend configuration:"
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
echo "  container_name       = \"$CONTAINER\""
echo "  key                  = \"dev.terraform.tfstate\""
echo ""
