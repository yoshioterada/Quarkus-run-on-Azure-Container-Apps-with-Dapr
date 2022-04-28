#!/bin/bash
set -e

if [ "$1" = "" ]
then
    echo "./build.sh [version-number]"
    exit 1
fi
export VERSION=$1

APPLICATION_NAME="back-service"
RESOURCE_GROUP="joad-container-apps"
CONTAINERAPPS_ENVIRONMENT="joad-env"

DOCKER_IMAGE=tyoshio2002/$APPLICATION_NAME
DOCKER_REPOSITORY=yoshio.azurecr.io

# Build docker image
docker build -t $DOCKER_IMAGE:$VERSION . -f Dockerfile
docker tag $DOCKER_IMAGE:$VERSION $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION

# Push the image to Private Docker Registry
docker push $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION

# Create Azure Container Apps Instance
# az containerapp create \
#   --name $APPLICATION_NAME \
#   --resource-group  $RESOURCE_GROUP\
#   --environment $CONTAINERAPPS_ENVIRONMENT \
#   --image  $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION\
#   --target-port 8080 \
#   --ingress 'external' \
#   --query 'configuration.ingress.fqdn' \
#   --cpu 1 --memory 2.0Gi \
#   --min-replicas 1 --max-replicas 4 \
#   --enable-dapr \
#   --dapr-app-port 8080 \
#   --dapr-app-id $APPLICATION_NAME

# Update Azure Container Apps Instance
az containerapp update \
 --name $APPLICATION_NAME \
 --resource-group $RESOURCE_GROUP \
 --image $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION

