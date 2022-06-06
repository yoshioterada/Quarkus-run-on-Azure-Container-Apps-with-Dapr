#!/bin/bash
set -e

if [ "$1" = "" ]
then
    echo "./build.sh [version-number]"
    exit 1
fi
export VERSION=$1

APPLICATION_NAME="back-service"
RESOURCE_GROUP="ms-love-java"
CONTAINERAPPS_ENVIRONMENT="jjug-env"


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

# Set Revision Mode to Multiple
# az containerapp revision set-mode --mode multiple  --name $APPLICATION_NAME  \
#   --resource-group  $RESOURCE_GROUP

OLD_BACKEND_RELEASE_NAME=$(az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP --query "[?properties.active == \`true\`].name" -o tsv)

echo "OLD Revision Name: " $OLD_BACKEND_RELEASE_NAME
echo "export OLD_BACKEND_RELEASE_NAME=" $OLD_BACKEND_RELEASE_NAME

# Update Azure Container Apps Instance
echo "Updating the Container Apps Instance ..."
CONTAINERAPP_UPDATE=$(az containerapp update \
 --name $APPLICATION_NAME \
 --resource-group $RESOURCE_GROUP \
 --image $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION)

echo $CONTAINERAPP_UPDATE

# Set Application Routing Ratio
echo "Configure Ingress Traffic Ratio ..."
CONFIGURE_INGRESS=$(az containerapp ingress traffic set \
  --name $APPLICATION_NAME \
  --resource-group  $RESOURCE_GROUP \
  --revision-weight \
  $OLD_BACKEND_RELEASE_NAME=80 \
  latest=20)

echo $CONFIGURE_INGRESS

# Show Current Revision
az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP -o table


# Set 100% Application Route to Latest Version
# az containerapp ingress traffic set \
#   --name $APPLICATION_NAME \
#   --resource-group  $RESOURCE_GROUP \
#   --revision-weight \
#   latest=100

# De-Activated the OLD Revision
# az containerapp revision deactivate \
#   --revision $OLD_BACKEND_RELEASE_NAME \
#   --name $APPLICATION_NAME  \
#   --resource-group  $RESOURCE_GROUP
