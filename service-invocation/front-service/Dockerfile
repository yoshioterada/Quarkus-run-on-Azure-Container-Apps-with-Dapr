## Stage 1 : build with maven builder image with native capabi lities
FROM quay.io/quarkus/ubi-quarkus-native-image:21.3.1-java11 AS build

COPY --chown=quarkus:quarkus mvnw /code/mvnw
COPY --chown=quarkus:quarkus .mvn /code/.mvn
COPY --chown=quarkus:quarkus pom.xml /code/
USER quarkus
WORKDIR /code


RUN ./mvnw -B org.apache.maven.plugins:maven-dependency-plugin:3.1.2:go-offline -Dmaven.repo.local=localrepos
COPY src /code/src
RUN ./mvnw package -Pnative -Dmaven.repo.local=localrepos

## Stage 2 : create the docker final image
FROM quay.io/quarkus/quarkus-micro-image:1.0
WORKDIR /work/
COPY --from=build /code/target/*-runner /work/application

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
ENV TZ=Asia/Tokyo

# set up permissions for user `1001`
RUN chmod 775 /work /work/application \
  && chown -R 1001 /work \
  && chmod -R "g+rwX" /work \
  && chown -R 1001:root /work

EXPOSE 8080
USER 1001

CMD ["./application", "-Dquarkus.http.host=0.0.0.0"]