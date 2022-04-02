# Please execute following
#
# docker build -f Dockerfile -t tyoshio2002/quarkus-msa:$COUNTER .
#
# docker tag tyoshio2002/quarkus-msa:$COUNTER yoshio.azurecr.io/tyoshio2002/quarkus-msa:$COUNTER
#
# docker push yoshio.azurecr.io/tyoshio2002/quarkus-msa:$COUNTER
#
######################################################
# RESOURCE_GROUP="joad-container-apps2"
# LOCATION="eastus"
# LOG_ANALYTICS_WORKSPACE="joad-container-apps-logs"
# CONTAINERAPPS_ENVIRONMENT="joad-environment"
######################################################
#
# az containerapp create \
#   --name dapper-state-java$COUNTER \
#   --resource-group $RESOURCE_GROUP \
#   --environment $CONTAINERAPPS_ENVIRONMENT \
#   --image yoshio.azurecr.io/tyoshio2002/quarkus-msa:$COUNTER \
#   --target-port 8080 \
#   --ingress 'external' \
#   --min-replicas 1 \
#   --max-replicas 1 \
#   --enable-dapr \
#   --dapr-app-port 3500 \
#   --dapr-app-id dapper-java$COUNTER \
#   --dapr-components ./components.yaml


# curl -v -X 'POST' \
#   'https://DAPR_INSTANCE_NAME.eastus.azurecontainerapps.io/post' \
#   -H 'accept: */*' \
#   -H 'Content-Type: application/json' \
#   -d '[
#   {
#     "key": "terada2",
#     "value": {
# 	"firstname": "Yoshio",
# 	"lastname" : "Terada",
# 	"email" : "yoshio.terada@microsoft.com",
# 	"address" : "Yokohama"
#     }
#   }
# ]'



## Stage 1 : build with maven builder image with native capabilities
FROM quay.io/quarkus/ubi-quarkus-native-image:21.3.1-java11 AS build

COPY --chown=quarkus:quarkus mvnw /code/mvnw
COPY --chown=quarkus:quarkus .mvn /code/.mvn
COPY --chown=quarkus:quarkus pom.xml /code/
USER quarkus
WORKDIR /code

RUN ./mvnw -B org.apache.maven.plugins:maven-dependency-plugin:3.1.2:go-offline
COPY src /code/src
RUN ./mvnw package -Pnative

## Stage 2 : create the docker final image
FROM quay.io/quarkus/quarkus-micro-image:1.0
WORKDIR /work/
COPY --from=build /code/target/*-runner /work/application

# set up permissions for user `1001`
RUN chmod 775 /work /work/application \
  && chown -R 1001 /work \
  && chmod -R "g+rwX" /work \
  && chown -R 1001:root /work

EXPOSE 8080
USER 1001

CMD ["./application", "-Dquarkus.http.host=0.0.0.0"]