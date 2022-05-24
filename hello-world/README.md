# はじめての Qurkus ネィティブ・イメージ on Azure Container Apps

## はじめに

Azure Container Apps は、マイクロソフトが Microsoft Ignite 2021 のイベントで(2021/11/04)で発表した技術で、本記事執筆時点で(2022/3/24)パブリック・プレビュー版として、提供されています。
本記事は、Azure Container Apps 上で Qurkus のネィティブ・イメージを利用して高速に起動し、Dapr の状態管理を利用する方法を紹介します。

## Azure Container Apps について

まず、初めに [Azure Container Apps](https://azure.microsoft.com/services/container-apps/) について簡単に紹介します。
Azure Container Apps はマイクロサービスのようなモダンなアプリケーションを、サーバ・レスのコンテナ環境で動作させることが可能な技術です。内部的に動作するコンテナは Kubernetes 上で稼働しますが、Kubernetes を隠蔽しているため、Kuberenetes を意識することなくサービスを動作させる事ができるようになります。また、動かすのはコンテナになりますので、サービスを実装するプログラミング言語はどの言語でも良く、幅広くご利用いただく事ができます。

どのような方にオススメかというと、たとえば、マイクロサービスのようなサービスをどんどんと増やしていきたい、そして既存のアプリケーションのバージョンアップも頻繁に行いたい、しかしその一方で Kubernetes に精通したエンジニアがいない、インフラの管理コストを下げたいと考えるような利用者に向くサービスになっています。もちろん、Kubernetes の全ての機能を利用できるわけではありません。ただ多くのシチュエーションにおいて Azure Container Apps が提供する機能で十分な場合もあります。現時点では本番環境での利用には向きませんが、サービスの正式リリース前に機能評価をしたいと考える技術者の皆様は、どうぞ本記事をご覧ください。

## Azure Container Apps の大表的な機能

Azure Container Apps が提供する代表的な機能を紹介します。

* [任意のプログラミング言語で利用可能](https://docs.microsoft.com/azure/container-apps/containers)
* [動作させるのはコンテナの為、比較的移植も用意](https://docs.microsoft.com/azure/container-apps/containers)
* [Kubernetes を隠蔽化した技術で簡単で便利なコマンドを用意](https://docs.microsoft.com/azure/container-apps/get-started-existing-container-image?tabs=bash)
* [サーバレスのため、動作するサーバのメンテナンス（パッチ適用など）は不要](https://docs.microsoft.com/azure/container-apps/environment)
* [リビジョン管理機能を持ちカナリア・リリースが容易](https://docs.microsoft.com/azure/container-apps/revisions)
* [新旧バージョンの入れ替えも容易](https://docs.microsoft.com/azure/container-apps/application-lifecycle-management)
* [Dapr](https://docs.dapr.io/concepts/overview/) を統合するため、[Dapr を利用したマイクロサービスの実装が可能](https://docs.microsoft.com/azure/container-apps/microservices-dapr?tabs=bash)
* [管理画面から GitHub 連携が可能で、GitHub Actions を利用した CI/CD が容易](https://docs.microsoft.com/azure/container-apps/github-actions-cli?tabs=bash)
* [豊富なスケーリング機能を提供（HTTP トラフィック、CPU, メモリの他、イベントドリブンでも設定可能 KEDA)](https://docs.microsoft.com/azure/container-apps/scale-app)

* 今後も正式リリースに向けて便利な機能が追加される事が予想されます。ぜひ最新動向をチェックしてください。

## Quarkus について

[Quarkus](https://quarkus.io/) は、Red Hat が主体となって開発をする Java のマイクロサービス開発用のフレームワークで、世界的に Java 業界では Spring に次ぐ人気となっています。
Quarkus は、Jakarta EE や MicroProfile で培った技術が利用可能なため、以前から Java EE を利用していた方には扱いやすいライブラリになっています。

## 本記事の進め方

1. Quarkus のプロジェクトを作成し、必要な Extension を追加します
2. Quarkus のネィティブイメージ作成用の Dockerfile を作成
3. Docker イメージ作成
4. Azure Container Registry にイメージをプッシュ
5. 構築時に必要な各種名前を環境変数に設定
6. リソース・グループを作成
7. Log Analytics を作成
8. Azure Container App Environment の作成
9. Azure Container App のインスタンスを作成
10. ログの確認
11.  アプリケーションの更新
12.  リビジョン管理
13.  コンソール・ログイン

## Azure Container Apps にデプロイするまで

### 1. Quarkus プロジェクトの作成

```bash
mvn io.quarkus.platform:quarkus-maven-plugin:2.8.2.Final:create \
    -DprojectGroupId=com.yoshio3 \
    -DprojectVersion=1.0.0-SNAPSHOT \
    -DclassName=com.yoshio3.Main \
    -Dpath="/hello" \
    -Dextensions="resteasy,resteasy-jackson" \
    -DprojectArtifactId=hello-world
```

コマンドを実行すると `hello-world` ディレクトリが作成されます。

```bash
cd hello-world
```

ディレクトリの中に入ると下記のようなファイルやディレクトリ構成が作成されている事を確認できます。

```text
├── README.md
├── mvnw
├── mvnw.cmd
├── pom.xml
└── src
    ├── main
    │   ├── docker
    │   │   ├── Dockerfile.jvm
    │   │   ├── Dockerfile.legacy-jar
    │   │   ├── Dockerfile.native
    │   │   └── Dockerfile.native-micro
    │   ├── java
    │   │   └── com
    │   │       └── yoshio3
    │   │           └── Main.java
    │   └── resources
    │       ├── META-INF
    │       │   └── resources
    │       │       └── index.html
    │       └── application.properties
    └── test
        └── java
            └── com
                └── yoshio3
                    ├── MainIT.java
                    └── MainTest.java
```

### 2. Quarkus のネィティブイメージ作成用の Dockerfile を作成

今回作成するサービスは [Graal VM](https://www.graalvm.org/) を利用し Linux のネィティブ・バイナリを作成します。
ネィティブ・バイナリは通常コンパイルする環境用に構築され、Windows なら Windows, Mac なら Mac、Linux なら Linux 用の実行バイナリが生成されます。

上記の Quarkus のプロジェクト作成時に自動的にいくつかの Dockerfile が生成されますが、今回は Docker のマルチステージ・ビルドで、ソースコードのコンパイルからコンテナイメージの作成までを行います。

[BUILDING A NATIVE EXECUTABLE](https://quarkus.io/guides/building-native-image#multistage-docker) にマルチステージ・ビルドを行うための Dockerfile のサンプルが記載されていますので、これを参考にしてネィティブ・イメージを作成します。

```text
## Stage 1 : build with maven builder image with native capabi lities
FROM quay.io/quarkus/ubi-quarkus-native-image:21.3.1-java11 AS build

COPY --chown=quarkus:quarkus mvnw /code/mvnw
COPY --chown=quarkus:quarkus .mvn /code/.mvn
COPY --chown=quarkus:quarkus pom.xml /code/
USER quarkus
WORKDIR /code

RUN ./mvnw -B org.apache.maven.plugins:maven-dependency-plugin:3.1.2:go-offline -Dmaven.repo.local=localrepos
COPY src /code/src
RUN ./mvnw package -Pnative -DskipTests -Dmaven.repo.local=localrepos

## Stage 2 : create the docker final image
FROM quay.io/quarkus/quarkus-micro-image:1.0
WORKDIR /work/
COPY --from=build /code/target/*-runner /work/application

## Set TimeZone
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
```

> 注意：  
> 上記の Dockerfile に下記の追記箇所がありますのでご注意ください。 Quarkus のコンテナ・イメージ (`quarkus-micro-image`) は Red Hat の Universal Base Image がベースになっています。デフォルトでタイムゾーンが日本時間に設定されていないため、アプリケーション・ログを確認すると 時間がずれるなどの不具合があります。そこでタイムゾーンを変更しています。

```text
## Set TimeZone
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
ENV TZ=Asia/Tokyo
```

### 3. Docker イメージ作成

上記の内容を Dockerfile というファイル名に記載した後、`docker build` コマンドでイメージを作成します。

```bash
docker build -f Dockerfile -t tyoshio2002/hello-world:1.0 .
```

はじめてコマンドを実行すると下記のようにファイルのコピーでエラーが発生するでしょう。

```text
 => ERROR [build 2/8] COPY --chown=quarkus:quarkus mvnw /code/mvnw                                 0.0s
 => ERROR [build 3/8] COPY --chown=quarkus:quarkus .mvn /code/.mvn                                 0.0s
 => ERROR [build 4/8] COPY --chown=quarkus:quarkus pom.xml /code/                                  0.0s
```

これは、Quarkus のプロジェクトを作成した際に、自動生成される `.dockerignore` というファイルが影響しているからです。
ファイルの内容を確認すると下記のように記述されており、`target` ディレクトリ配下の一部を除く、全てのファイルが `COPY` できないようになっています。

```text
*
!target/*-runner
!target/*-runner.jar
!target/lib/*
!target/quarkus-app/*
```

今回は、`mvnw`, `.mvn`, `pom.xml`, `src` のファイルを `COPY` する為、`.dockerignore` ファイルを削除します。

```bash
rm .dockerignore
```

> ご注意：  
`.dockerignore` ファイルが存在するために、ファイルの `ADD` や `COPY` ができない事象は、経験者でもたまに見落とす事があるため、どうぞご注意ください。

これで、`docker build` コマンドを実行できるようになりましたので、コマンドを実行します。

```bash
docker build -f Dockerfile -t tyoshio2002/hello-world:1.0 .
```

正常に完了した後、イメージが正しく作成されているか `docker images` コマンドで確認してみましょう。
これをご確認いただくとわかるように、コンテナのイメージサイズが 100MB 程度で、Java のコンテナイメージとしては比較的小さなイメージができていることが確認できます。

```bash
docker images 
REPOSITORY                TAG    IMAGE ID       CREATED          SIZE
tyoshio2002/hello-world   1.0    af977612bd02   33 minutes ago   130MB
```

最後に、Quarkus の Web アプリケーションが正しく動作するかを確認します。`docker run` コマンドを実行し、コンテナを起動してください。Quarkus はデフォルトで `8080` 番ポートで HTTP ポートをオープンしています。そこで `8080` 番ポートに外部からアクセスできるように引数を指定しています。

```bash
docker run -p 8080:8080 -it  tyoshio2002/hello-world:1.0
__  ____  __  _____   ___  __ ____  ______ 
 --/ __ \/ / / / _ | / _ \/ //_/ / / / __/ 
 -/ /_/ / /_/ / __ |/ , _/ ,< / /_/ /\ \   
--\___\_\____/_/ |_/_/|_/_/|_|\____/___/   
2022-04-28 22:41:22,686 INFO  [io.quarkus] (main) hello-world 1.0.0-SNAPSHOT native (powered by Quarkus 2.8.2.Final) started in 0.017s. Listening on: http://0.0.0.0:8080
2022-04-28 22:41:22,686 INFO  [io.quarkus] (main) Profile prod activated. 
2022-04-28 22:41:22,686 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, resteasy-jackson, smallrye-context-propagation, vertx]
```

コンテナが正常に起動できたのち、`curl` コマンドを実行してください。正しく動作している場合、`Hello RESTEasy` の文字が出力されます。

```bash
$ curl localhost:8080/hello
Hello RESTEasy
```

この文字列は `src/main/java/com/yoshio3/Main.java` に記載されているコードが呼び出されています。

```java
@Path("/hello")
public class Main {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return "Hello RESTEasy";
    }
}
```

### 4. Azure Container Registry にイメージをプッシュ

コンテナのイメージを作成したので、次にイメージにタグ付けを行い、Container Registry にプッシュします。
コンテナのタグ付けを行うためには、`docker tag` コマンドを実行し、Container Registry にプッシュするために `docker push` コマンドを実行します。

```bash
docker tag  tyoshio2002/hello-world:1.0 yoshio.azurecr.io/tyoshio2002/hello-world:1.0
docker push yoshio.azurecr.io/tyoshio2002/hello-world:1.0
```

仮に、コンテナ・レジストリとして `Azure Container Registry` を利用し `Azure CLI` コマンドを利用している場合は、コンテナ・イメージのデプロイからプッシュまでの一連の流れを下記のコマンド１回で実行できます。

```azurecli
az acr build -t  tyoshio2002/hello-world:1.1 -r ACR_NAME -g $RESOURCE_GROUP .
```

これは、リモートの Azure Container Registry 上でコンテナのビルドを行い、そのままイメージをプッシュできるため、とても便利です。特に、ローカル環境で Docker デスクトップをインストールしていない、もしくはできないような場合に有効です。

最後に、Azure Container Registry に正しくイメージがプッシュされているかを確認するため `az acr repository show` コマンドを実行してください。正しくアップロードされている場合、下記のような結果が表示されます。

```azurecli
az acr repository show -n $YOUR_AZURE_CONTAINER_REGISTRY --image tyoshio2002/hello-world:1.0
{
  "changeableAttributes": {
    "deleteEnabled": true,
    "listEnabled": true,
    "readEnabled": true,
    "writeEnabled": true
  },
  "createdTime": "2022-04-25T02:21:42.4321004Z",
  "digest": "sha256:0564725591c905731b7f44f226610d1b7496aa755fb111c62f0e15cb950e9d97",
  "lastUpdateTime": "2022-04-25T02:21:42.4321004Z",
  "name": "1.0",
  "quarantineState": "Passed",
  "signed": false
}
```

以上で、Quarkus で実装した Java の Web アプリケーションをコンテナ化し、コンテナ・レジストリにコンテナ・イメージをプッシュしました。そこで、ここから実際に、Azure Container Apps の環境を作成したいと思います。

### 5. 構築時に必要な各種名前を環境変数に設定

以降で、実際に Azure Container Apps を作成していきます。  
まず、コマンド実行時に繰り返し指定する名前を環境変数に設定します。

```bash
export RESOURCE_GROUP="ms-love-java"
export LOCATION="japaneast"
export LOG_ANALYTICS_WORKSPACE="jjug-containerapps-logs"
export CONTAINERAPPS_ENVIRONMENT="jjug-env"
export APPLICATION_NAME="hello-service"
```

上記はそれぞれ、`リソース・グループ名`、`インストール場所`、`ログ・アナリティクスのワークスペース名`、`Container Apps 環境名`、`アプリケーション名` を設定しています。

> 注意：  
> 上記の各種サービス名は適宜修正をしてください。
> 2022/5 現在 Azure Container Apps をインストールできるロケーションは `North Central US, Canada Central, West Europe, North Europe, East US, East US 2, East Asia, Australia East, Germany West Central, Japan East, UK South, West US` です

### 6. リソース・グループを作成

それでは、Azure Container Apps を管理するためのリソース・グループを作成しましょう。`az group create` コマンドを実行してリソース・グループを作成してください。

```azurecli
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 7. Log Analytics を作成

次に、Azure Monitor Log Analytics を作成します。`az monitor log-analytics workspace create` コマンドを実行し作成してください。

```azurecli
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION  \
  --workspace-name $LOG_ANALYTICS_WORKSPACE
```

Log Analytics のワーク・スペースの IDと接続用のパスワードを Container Apps の環境構築時に使用するため、ID などの情報を取得し環境変数に設定します。

```text
LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`
```

### 8. Azure Container Apps 環境の作成

まず、Azure Container Apps の環境を構築します。ここで構築する環境は、セキュリティに保護されたコンテナ・アプリケーションの境界が作成されます。 同じ環境上にデプロイした Container Apps は、同一仮想ネットワークや同一 Log Analytics ワークスペースを利用します。

Azure Container Apps の環境を構築するため、`az containerapp env create` コマンドを実行してください。

```azurecli
az containerapp env create \
  --name $CONTAINERAPPS_ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
  --location $LOCATION
```

### 9. Azure Container Apps のインスタンスを作成

Azure Container Apps を構築するための準備が終わったので、Container Apps のインスタンスを作成します。`az containerapp create` コマンドを実行し Container Apps インスタンスを作成してください。

```azurecli
az containerapp create \
  --name $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image yoshio.azurecr.io/tyoshio2002/hello-world:1.0\
  --target-port 8080 \
  --ingress 'external' \
  --query 'configuration.ingress.fqdn' \
  --cpu 1 --memory 2.0Gi \
  --min-replicas 1 --max-replicas 4
```

コマンドが正常に完了すると、下記のように外部から接続可能な URL が表示されます。

```text
Container app created. 
Access your app at 
https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/
```

表示された URL に対して、ブラウザもしくは `curl` コマンドなどでアクセスしてください。

```bash
curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello RESTEasy
```

正しくデプロイされている場合、`Hello RESTEasy` という文字列が表示されます。

### 10. ログの確認（クエリの実行）

Azure Container Apps 上でアプリケーションが動作しているので、アプリケーションのログを確認します。

#### 10.1 Azure CLI コマンドによるログ・ストリームの確認

`az containerapp logs show` コマンドを実行してログ・ストリームを確認してみましょう。

```azurecli
 az containerapp logs show --name $APPLICATION_NAME --resource-group $RESOURCE_GROUP   --tail 100
```

コマンドを実行すると下記の結果が表示されまs。

```text
Command group 'containerapp logs' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
{"TimeStamp":"2022-05-23T04:31:14.10523","Log":"Connecting to the container 'hello-service'..."}
{"TimeStamp":"2022-05-23T04:31:14.12406","Log":"Successfully Connected to container: 'hello-service' [Revision: 'hello-service--hl8xrh6', Replica: 'hello-service--hl8xrh6-77b5f965d-ssh9l']"}
{"TimeStamp":"2022-05-23T04:29:05.3103867+00:00","Log":"____  __  _____   ___  __ ____  ______"}
{"TimeStamp":"2022-05-23T04:29:05.3104058+00:00","Log":"--/ __ \\/ / / / _ | / _ \\/ //_/ / / / __/"}
{"TimeStamp":"2022-05-23T04:29:05.3104091+00:00","Log":"-/ /_/ / /_/ / __ |/ , _/ ,\u003C / /_/ /\\ \\"}
{"TimeStamp":"2022-05-23T04:29:05.3104115+00:00","Log":"|_/_/|_/_/|_|\\____/___/"}
{"TimeStamp":"2022-05-23T04:29:05.3104137+00:00","Log":"13:29:05,310 INFO  [io.quarkus] (main) hello-world 1.0.0-SNAPSHOT native (powered by Quarkus 2.8.2.Final) started in 0.011s. Listening on: http://0.0.0.0:8080"}
{"TimeStamp":"2022-05-23T04:29:05.3104165+00:00","Log":"13:29:05,310 INFO  [io.quarkus] (main) Profile prod activated."}
{"TimeStamp":"2022-05-23T04:29:05.3104324+00:00","Log":"13:29:05,310 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, resteasy-jackson, smallrye-context-propagation, vertx]"}

```

#### 10.2 Log Analytics に格納されているログを確認

`az monitor log-analytics query` コマンドを実行してログを確認してみましょう。

```azurecli
az monitor log-analytics query \
  -w $LOG_ANALYTICS_WORKSPACE_CLIENT_ID  \
  --analytics-query "ContainerAppConsoleLogs_CL|
    where TimeGenerated > ago(10m) |
    where ContainerAppName_s == 'hello-service' |
    project Log_s |
    take 500" -o tsv
```

分かりやすくするため、クエリ部分だけを抽出すると下記のクエリを実行しています。

```text
ContainerAppConsoleLogs_CL|
    where TimeGenerated > ago(10m) |
    where ContainerAppName_s == 'hello-service' |
    project Log_s |
    take 500
```

コマンドを実行すると下記のような内容が表示されます。

```text
__  ____  __  _____   ___  __ ____  ______ 	PrimaryResult
 --/ __ \/ / / / _ | / _ \/ //_/ / / / __/ 	PrimaryResult
 -/ /_/ / /_/ / __ |/ , _/ ,< / /_/ /\ \   	PrimaryResult
--\___\_\____/_/ |_/_/|_/_/|_|\____/___/   	PrimaryResult
2022-04-28 23:06:43,998 INFO  [io.quarkus] (main) hello-world 1.0.0-SNAPSHOT native (powered by Quarkus 2.8.2.Final) started in 0.011s. Listening on: http://0.0.0.0:8080	PrimaryResult
2022-04-28 23:06:43,999 INFO  [io.quarkus] (main) Profile prod activated. 	PrimaryResult
2022-04-28 23:06:43,999 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, resteasy-jackson, smallrye-context-propagation, vertx]PrimaryResult
```

> 注意：Log Analytics で管理する `PrimaryResult` はテーブル名で実際のアプリケーション・ログではありません。  
> Azure Portal からも同じクエリを実行しブラウザ上で確認することも可能です。
> アプリケーション・ログの確認方法は現在決して多くなく、将来的に改善される事を期待しています。  
> Enhancement Request: [Logging of Containers hosted in Container Apps](https://github.com/microsoft/azure-container-apps/issues/49)


### 11. アプリケーションの更新

上記では、Quarkus のプロジェクトを作成した際にデフォルトで作成された Java のソースコードをそのまま利用しました。そこで一部のコードを修正して Azure Container Apps のインスタンスを更新します。`Main.java` ファイルを開き文字列を書き換えてみましょう。

```java
@Path("/hello")
public class Main {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return "Hello Quarkus on Azure Contaienr Apps!!";
    }
}
```

次に、Azure Container Apps インスタンスの更新を簡単にするために、シェル・スクリプト ( `build.sh`) を作成し下記の内容を記述してください。

```bash
#!/bin/bash
set -e

if [ "$1" = "" ]
then
    echo "./build.sh [version-number]"
    exit 1
fi
export VERSION=$1

# Config Parameter (Need Change This Value !!) 
###################################
export APPLICATION_NAME="hello-service"
export RESOURCE_GROUP="ms-love-java"
export CONTAINERAPPS_ENVIRONMENT="jjug-env"

DOCKER_IMAGE=tyoshio2002/$APPLICATION_NAME
DOCKER_REPOSITORY=yoshio.azurecr.io
###################################

###################################
# Build docker image
docker build -t $DOCKER_IMAGE:$VERSION . -f Dockerfile
docker tag $DOCKER_IMAGE:$VERSION $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION
# Push the image to Private Docker Registry
docker push $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION

###################################
# Update Azure Container Apps Instance
az containerapp update \
 --name $APPLICATION_NAME \
 --resource-group $RESOURCE_GROUP \
 --image $DOCKER_REPOSITORY/$DOCKER_IMAGE:$VERSION
```

ファイルを作成した後、ファイルに実行権限を与えます。

```bash
chmod 755 build.sh
```

最後に、シェル・スクリプトを実行してください。

```bash
./build.sh 1.1
```

シェル・スクリプトを実行すると、コンテナ・イメージの作成、コンテナ・レジストリへのプッシュ、Azure Container Apps インスタンスの更新が全て行われます。

更新が完了したのち、先ほど作成したアプリケーションのインスタンスと同じ URL にアクセスしてください。

```bash
curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello Quarkus on Azure Contaienr Apps!!
```

プログラムで修正した文字列が表示されていることが確認できます。

### 12. リビジョン管理

現時点で、最初にデプロイしたバージョンと、文字列を修正した新しいバージョンの２つのバージョンをデプロイしています。現在デプロイされているリビジョンの一覧を確認してください。

```azurecli
az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  -o table
```

実行すると、下記のようにリビジョンの一覧を確認できます。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ----------------------
2022-04-28T14:06:33+00:00  False     0                hello-service--nxgb5ib
2022-04-28T14:35:59+00:00  True      100              hello-service--medtdh6
```

`TrafficWeight` の行を確認すると全リクエスト (100%) が最新バージョンへ振り分けられています。
仮に、新旧バージョンでリクエストのルーティング比率を変えたい場合は、下記の手順で変更できます。

まず、`az containerapp revision set-mode` コマンドで `multiple` を指定し実行します。すると複数のインスタンスを同時に `Active` にできます。

```azurecli
az containerapp revision set-mode --mode multiple  --name $APPLICATION_NAME  \
  --resource-group  $RESOURCE_GROUP
```

次に非アクティブになっているインスタンス `hello-service--nxgb5ib` をアクティブ化します。
`az containerapp revision activate` コマンドを実行しアクティブにします。

```azurecli
az containerapp revision activate \
  --revision hello-service--nxgb5ib \
  --name $APPLICATION_NAME  \
  --resource-group  $RESOURCE_GROUP
```

再度、リビジョンの一覧を確認してください。

```azurecli
az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  -o table
```

実行すると両方のインスタンスの `Active` 列が  `True` にかわります。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ----------------------
2022-04-28T14:06:33+00:00  True      0                hello-service--nxgb5ib
2022-04-28T14:35:59+00:00  True      100              hello-service--medtdh6
```

複数のインスタンスを `Active` に変更した後、ルーティングの比率 (50:50) を変更します。

```azurecli
az containerapp ingress traffic set \
  --name $APPLICATION_NAME \
  --resource-group  $RESOURCE_GROUP \
  --traffic-weight \
  hello-service--nxgb5ib=50 \
  hello-service--medtdh6=50
```

トラフィックの比率を変更したのち再度インスタンスの状態を確認してください。

```azurecli
az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  -o table
```

コマンドを実行すると、下記の結果が得られます。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ----------------------
2022-04-28T14:06:33+00:00  True      50               hello-service--nxgb5ib
2022-04-28T14:35:59+00:00  True      50               hello-service--medtdh6
```

リクエストの振り分け比率を変更した後、実際にエンドポイントにアクセスしてみます。するとリクエストがそれぞれのインスタンスに振り分けられている事を確認できます。

```bash
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello RESTEasy
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello Quarkus on Azure Contaienr Apps!!
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello RESTEasy
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello RESTEasy
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello RESTEasy
% curl https://hello-service.orangeglacier-2ac553ea.eastus.azurecontainerapps.io/hello
Hello Quarkus on Azure Contaienr Apps!!
```

新しいバージョンで問題ない事を確認し、ある程度稼働が安定したのち、全リクエストを新しいインスタンスに割り当てます。新しいインスタンスに対して振り分け比率を 100% に設定します。

```azurecli
az containerapp ingress traffic set \
  --name $APPLICATION_NAME \
  --resource-group  $RESOURCE_GROUP \
  --traffic-weight \
    hello-service--nxgb5ib=0 \
    hello-service--medtdh6=100
```

最後に、古いインスタンスを非アクティブに変更します。

```azurecli
az containerapp revision deactivate \
  --revision hello-service--nxgb5ib \
  --name $APPLICATION_NAME  \
  --resource-group  $RESOURCE_GROUP
```

再度、リビジョンのリストを確認してください。

```azurecli
az containerapp revision list \
   -n $APPLICATION_NAME \
   --resource-group $RESOURCE_GROUP \
   -o table
```

コマンドの実行結果を確認すると、古いインスタンスの `Active` 項目が `False` になり `TrafficWeight` も `0` になっている事が確認できます。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ----------------------
2022-04-28T14:06:33+00:00  False     0                hello-service--nxgb5ib
2022-04-28T14:35:59+00:00  True      100              hello-service--medtdh6
```

> 注意：  
> 新しくデプロイしたのは traffic rate 0 でデプロイしてほしかったのですが、仕様との事です。
> Issue: [Request to have a functionality of the update with traffic weight=0](https://github.com/microsoft/azure-container-apps/issues/23)


### 1３. コンソール・ログイン

Azure CLI を利用してコンテナのコンソールに接続できるようになっています
`az containerapp exec` コマンドを実行してください。

```azurecli
az containerapp exec --name $APPLICATION_NAME --resource-group $RESOURCE_GROUP   
```

実行すると下記のような結果が表示されます。

```bash
Command group 'containerapp' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
INFO: Connecting to the container 'hello-service'...
Use ctrl + D to exit.
INFO: Successfully connected to container: 'hello-service'. [ Revision: 'hello-service--hl8xrh6', Replica: 'hello-service--hl8xrh6-77b5f965d-ssh9l']
sh-4.4$ uname -a
Linux hello-service--hl8xrh6-77b5f965d-ssh9l 5.4.0-1078-azure #81~18.04.1-Ubuntu SMP Mon Apr 25 23:16:13 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
sh-4.4$ ls
application
```

## まとめ

今回は、Quarkus のネィティブ・アプリケーションをコンテナで作成し Azure Container Apps にデプロイする方法を紹介しました。ログ・アナリティクスを利用してログを確認したり、シェル・スクリプトを作成して更新を簡単にすることができました。次は、[Azure Container Apps で Dapr を利用した Service 間呼び出し](../service-invocation/README.md)を行います。
