# Azure Container Apps 上で Qurkus のネィティブ・イメージを利用して高速に起動し、Dapr の状態管理を利用する

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
10. ログの確認（クエリの実行）
11. Azure Container App インスタンスの更新
12. リビジョン管理
13. Redis 環境の構築
14. Dapr の状態管理のコードを実装
15. Dapr のコンポーネント設定ファイルの作成
16. Azure Container App インスタンスの作成
17. Azure Container App インスタンスの更新

## Azure Container Apps にデプロイするまで

### 1. Quarkus プロジェクトの作成

```bash
$ mvn io.quarkus.platform:quarkus-maven-plugin:2.7.5.Final:create \
    -DprojectGroupId=com.yoshio3 \
    -DprojectVersion=1.0.0-SNAPSHOT \
    -DclassName=com.yoshio3.Main \
    -Dpath="/hello" \
    -DprojectArtifactId=quarkus-msa
```

コマンドを実行すると `quarkus-msa` ディレクトリが作成され下記のようなファイルが自動生成されます。

```bash
cd quarkus-msa
```

すると下記のようなファイルやディレクトリ構成が作成されています。

```text
├── README.md
├── .dockerignore
├── .gitignore
├── .mvn
│   └── wrapper
│       ├── MavenWrapperDownloader.java
│       └── maven-wrapper.properties
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
                    ├── MainTest.java
                    └── NativeMainIT.java
```

### 2. Quarkus のネィティブイメージ作成用の Dockerfile を作成

今回作成するサービスは Graal VM を利用したネィティブ・バイナリを作成するようにします。
ネィティブ・バイナリは通常コンパイルする環境用に構築されるため、Windows なら Windows, Mac なら Mac、Linux なら Linux 用の実行バイナリが生成されます。（Linuxバイナリ生成用のオプションはある）
今回コンテナ上で Java アプリケーションを起動する為、ソースコードのコンパイルも、コンテナのビルド時に Linux 環境で同時に行います。

上記の Quarkus のプロジェクト作成時に自動的にいくつかの Dockerfile が生成されますが、今回は Docker のマルチステージ・ビルドで、ソースコードのコンパイルからコンテナイメージの作成までを行います。

[BUILDING A NATIVE EXECUTABLE](https://quarkus.io/guides/building-native-image#multistage-docker) にマルチステージ・ビルドを行うための Dockerfile のサンプルが記載されていますので、これを利用してネィティブ・イメージを作成したいと思います。

```text
## Stage 1 : build with maven builder image with native capabi lities
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
```

### 3. Docker イメージ作成

上記の内容を Dockerfile というファイル名に記載した後、`docker build` コマンドでイメージを作成します。

```bash
docker build -f Dockerfile -t tyoshio2002/quarkus-sample:1.0 .
```

はじめてコマンドを実行すると下記のようにファイルのコピーでエラーが発生するでしょう。

```text
 => ERROR [build 2/8] COPY --chown=quarkus:quarkus mvnw /code/mvnw                                 0.0s
 => ERROR [build 3/8] COPY --chown=quarkus:quarkus .mvn /code/.mvn                                 0.0s
 => ERROR [build 4/8] COPY --chown=quarkus:quarkus pom.xml /code/                                  0.0s
 => CACHED [build 5/8] WORKDIR /code                                                               0.0s
 => CACHED [build 6/8] RUN ./mvnw -B org.apache.maven.plugins:maven-dependency-plugin:3.1.2:go-of  0.0s
 => ERROR [build 7/8] COPY src /code/src                                                           0.0s
------
 > [build 2/8] COPY --chown=quarkus:quarkus mvnw /code/mvnw:
------
------
 > [build 3/8] COPY --chown=quarkus:quarkus .mvn /code/.mvn:
------
------
 > [build 4/8] COPY --chown=quarkus:quarkus pom.xml /code/:
------
------
 > [build 7/8] COPY src /code/src:
------
failed to compute cache key: "/src" not found: not found
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
docker build -f Dockerfile -t tyoshio2002/quarkus-sample:1.0 .
```

正常に完了した後、イメージが正しく作成されているか `docker images` コマンドで確認してみましょう。
これをご確認いただくとわかるように、コンテナのイメージサイズが 100MB 程度で、Java のコンテナイメージとしては比較的小さなイメージができていることが確認できます。

```bash
$ docker images | grep quarkus-sample
REPOSITORY                                  TAG              IMAGE ID       CREATED         SIZE
tyoshio2002/quarkus-sample                  1.0              a1a568daf7e0   2 minutes ago   121MB
```

最後に、Quarkus の Web アプリケーションが正しく動作するかを確認します。`docker run` コマンドを実行し、コンテナを起動してください。Quarkus はデフォルトで `8080` 番ポートで HTTP ポートをオープンしています。そこで `8080` 番ポートに外部からアクセスできるように引数を指定しています。

```bash
$ docker run -p 8080:8080 -it tyoshio2002/quarkus-sample:1.0
__  ____  __  _____   ___  __ ____  ______ 
 --/ __ \/ / / / _ | / _ \/ //_/ / / / __/ 
 -/ /_/ / /_/ / __ |/ , _/ ,< / /_/ /\ \   
--\___\_\____/_/ |_/_/|_/_/|_|\____/___/   
2022-03-25 05:36:32,419 INFO  [io.quarkus] (main) quarkus-msa 1.0.0-SNAPSHOT native (powered by Quarkus 2.7.5.Final) started in 0.014s. Listening on: http://0.0.0.0:8080
2022-03-25 05:36:32,420 INFO  [io.quarkus] (main) Profile prod activated. 
2022-03-25 05:36:32,420 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, smallrye-context-propagation, vertx]
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
        return "Hello Java on Azure !!";
    }
}
```

### 4. Azure Container Registry にイメージをプッシュ

コンテナのイメージを作成したので、次にイメージにタグ付けを行い、Container Registry にプッシュします。
コンテナのタグ付けを行うためには、`docker tag` コマンドを実行し、Container Registry にプッシュするために `docker push` コマンドを実行します。

```bash
docker tag tyoshio2002/quarkus-sample:1.0 yoshio.azurecr.io/tyoshio2002/quarkus-sample:1.0
docker push yoshio.azurecr.io/tyoshio2002/quarkus-sample:1.0
```

仮に、コンテナ・レジストリとして `Azure Container Registry` を利用し `Azure CLI` コマンドを利用している場合は、コンテナ・イメージのデプロイからプッシュまでの一連の流れを下記のコマンド１回で実行できます。

```azurecli
az acr build -t  tyoshio2002/quarkus-sample:1.1 -r ACR_NAME -g $RESOURCE_GROUP .
```

これは、ローカルの環境で docker デスクトップ等をインストールしていない場合にリモートでビルドを行い、そのまま `Azure Container Registry` にイメージをプッシュできるためとても便利です。

以上で、Quarkus で実装した Java の Web アプリケーションをコンテナ・レジストリにプッシュしたので、ここから実際に、Azure Container Apps の環境を作成したいと思います。

### 5. 構築時に必要な各種名前を環境変数に設定

以降で、実際に Azure Container Apps を作成していきます。今度コマンド実行時に繰り返し指定する各種サービス名を事前に環境変数に設定しておきます。具体的には、`リソース・グループ名`、`インストール場所`、`ログ・アナリティクスのワークスペース名`、`Container Apps Env` の名前を環境変数に設定します。

```bash
export RESOURCE_GROUP="joad-container-apps"
export LOCATION="eastus"
export LOG_ANALYTICS_WORKSPACE="joad-containerapps-logs"
export CONTAINERAPPS_ENVIRONMENT="joad-env"
export APPLICATION_NAME="quarkus-micro-service"
```

> 注意：  
> 上記の各種サービス名は適宜修正をしてください。
> 2022/3/25 現在 Azure Container Apps をインストールできるロケーションは `North Central US (Stage)`,`Canada Central`,`West Europe`,`North Europe`,`East US`,`East US 2` です

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

### 8. Azure Container Apps Environment の作成

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
  --image yoshio.azurecr.io/tyoshio2002/quarkus-sample:1.0 \
  --target-port 8080 \
  --ingress 'external' \
  --query 'configuration.ingress.fqdn' \
  --cpu 1 --memory 2.0Gi \
  --min-replicas 1 --max-replicas 4
```

コマンドが正常に完了すると、下記のように外部から接続可能な URL が表示されます。

```text
Container app created. Access your app at https://$APPLICATION_NAME.jollymeadow-04b7a3f0.eastus.azurecontainerapps.io/
```

表示された URL に対して、ブラウザもしくは `curl` コマンドなどでアクセスしてください。

```bash
curl https://$APPLICATION_NAME.jollymeadow-04b7a3f0.eastus.azurecontainerapps.io/hello
Hello RESTEasy
```

正しくデプロイされている場合、`Hello RESTEasy` という文字列が表示されます。

### 10. ログの確認（クエリの実行）

Azure Container Apps 上でアプリケーションが動作しているので、アプリケーションのログを確認します。`az monitor log-analytics query` コマンドを実行してログを確認してみましょう。

```azurecli
az monitor log-analytics query \
  -w $LOG_ANALYTICS_WORKSPACE_CLIENT_ID  \
  --analytics-query "ContainerAppConsoleLogs_CL|  \
    where ContainerAppName_s == '$APPLICATION_NAME' \
    | project Log_s | take 200" -o tsv
```

分かりやすくするため、クエリ部分だけを抽出すると下記のクエリを実行しています。

```text
ContainerAppConsoleLogs_CL 
| where ContainerAppName_s == '$APPLICATION_NAME' 
| project Log_s 
| take 200
```

コマンドを実行すると下記のような内容が表示されます。

```text
__  ____  __  _____   ___  __ ____  ______ 　PrimaryResult
 --/ __ \/ / / / _ | / _ \/ //_/ / / / __/ 　PrimaryResult
 -/ /_/ / /_/ / __ |/ , _/ ,< / /_/ /\ \   　PrimaryResult
--\___\_\____/_/ |_/_/|_/_/|_|\____/___/   　PrimaryResult
2022-03-25 06:25:23,872 INFO  [io.quarkus] (main) quarkus-msa 1.0.0-SNAPSHOT native (powered by Quarkus 2.7.5.Final) started in 0.011s. Listening on: http://0.0.0.0:8080	PrimaryResult
2022-03-25 06:25:23,872 INFO  [io.quarkus] (main) Profile prod activated. 　PrimaryResult
2022-03-25 06:25:23,873 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy, smallrye-context-propagation, vertx]　PrimaryResult
　PrimaryResult
　PrimaryResult
```

> 注意：Log Analytics で管理する `PrimaryResult` はテーブル名で実際のアプリケーション・ログではありません。  
> Azure Portal からも同じクエリを実行しブラウザ上で確認することも可能です。
> アプリケーション・ログの確認方法は現在決して多くなく、将来的に改善される事を期待しています。  
> Enhancement Request: [Logging of Containers hosted in Container Apps](https://github.com/microsoft/azure-container-apps/issues/49)

## デモはここから

### 11. Azure Container App インスタンスの更新

Azure Container Apps 上でアプリケーションを動作させる事ができましたので、Java のソースコードを修正し、アプリケーションを更新してみたいと思います。

修正する Java のソースコードは２ヶ所で、それぞれ `Hello RESTEasy` と記載されている箇所を `Hello Java on Azure !!` に置き換えてファイルを上書き保存してください。

`src/main/java/com/yoshio3/Main.java`

```java
    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return "Hello Java on Azure !!";
    }
```

`src/test/java/com/yoshio3/MainTest.java`

```java
    @Test
    public void testHelloEndpoint() {
        given()
         .when().get("/hello")
          .then()
             .statusCode(200)
             .body(is("Hello Java on Azure !!"));
    }
```

Java のソースコードを編集した後、コンテナのイメージを再ビルドしコンテナ・レジストリにプッシュします。前回作業では、個別にコマンドを実行しましたが、今後更新が頻繁に発生することも考慮し、コンテナ・イメージのタグを環境変数に設定することにします。

```bash
export VERSION_TAG_OF_IMAGE=1.1
docker build -f Dockerfile -t tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE .
docker tag tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
docker push yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
```

再ビルドしたコンテナのイメージをコンテナ・レジストリにプッシュしたので、Azure Container Apps のインスタンスのコンテナ・イメージも更新します。Container Apps を更新する為に `az containerapp update` コマンドを実行してください。

```azurecli
az containerapp update \
  --name  $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  --image yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
```

正しく、更新された場合、ブラウザもしくは `curl` コマンドなどでアクセスし表示内容が更新されている事を確認してください。

```bash
curl https://$APPLICATION_NAME.purplesmoke-8fac7236.eastus.azurecontainerapps.io/hello
Hello Java on Azure !!
```

### 12. リビジョン管理

現在、最初にデプロイしたバージョンと、プログラムを修正した新しいバージョンの２つのバージョンをデプロイしています。現在デプロイされているリビジョンの一覧を確認する為に コマンドを実行してください。

```azurecli
az containerapp revision list \
  -n $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  -o table
```

実行すると、下記のようにリビジョンの一覧を確認できます。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ------------------------------
2022-04-02T04:34:35+00:00  False     0                quarkus-micro-service--jr4tixl
2022-04-02T06:08:23+00:00  True      100              quarkus-micro-service--g9x6s1u
```

全リクエストが最新バージョンへルーティングされています。
仮に、新旧バージョンでリクエストのルーティング比率を変えを分散させたい場合は、`az containerapp revision set-mode` コマンドで `multiple` を指定し実行します。すると複数のインスタンスを `Active` にする事ができるようになります。

```azurecli
az containerapp revision set-mode --mode multiple  --name $APPLICATION_NAME  \       
  --resource-group  $RESOURCE_GROUP
```

複数のインスタンスを `Active` に変更した後、ルーティングの比率を変更します。

```azurecli
az containerapp ingress traffic set \   
  --name $APPLICATION_NAME \                                            
  --resource-group  $RESOURCE_GROUP \
  --traffic-weight \
    quarkus-micro-service--jr4tixl=50 \
    quarkus-micro-service--g9x6s1u=50
```

トラフィックの比率を変更した確認すると、下記の結果が得られます。

```azurecli
az containerapp revision list \
  -n $APPLICATION_NAME \                                            
  --resource-group $RESOURCE_GROUP \
  -o table

CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ------------------------------
2022-04-02T04:34:35+00:00  True      50               quarkus-micro-service--jr4tixl
2022-04-02T06:08:23+00:00  True      50               quarkus-micro-service--g9x6s1u

```

新しいバージョンで問題ない事を確認し稼働が安定した後、全リクエストを新しいインスタンスに割り当てます。

```azurecli
az containerapp ingress traffic set \   
  --name $APPLICATION_NAME \
  --resource-group  $RESOURCE_GROUP \
  --traffic-weight \
    quarkus-micro-service--jr4tixl=0 \
    quarkus-micro-service--g9x6s1u=100
```

そして、最後に古いインスタンスを非アクティブに変更します。

```azurecli
az containerapp revision deactivate \
  --revision quarkus-micro-service--jr4tixl \
  --name $APPLICATION_NAME  \
  --resource-group  $RESOURCE_GROUP
```

再度、リビジョンのリストを確認してください。

```azurecli
az containerapp revision list -n $APPLICATION_NAME --resource-group $RESOURCE_GROUP -o table
```

コマンドの実行結果を確認すると、古いインスタンスの `Active` 項目が `False` になり `TrafficWeight` の数も `0` になっている事が確認できます。

```text
CreatedTime                Active    TrafficWeight    Name
-------------------------  --------  ---------------  ------------------------------
2022-04-02T04:34:35+00:00  False     0                quarkus-micro-service--jr4tixl
2022-04-02T06:08:23+00:00  True      100              quarkus-micro-service--g9x6s1u
```

> 注意：  
> 新しくデプロイしたのは traffic rate 0 でデプロイしてほしかったのですが、仕様との事です。
> Issue: [Request to have a functionality of the update with traffic weight=0](https://github.com/microsoft/azure-container-apps/issues/23)

### 13. Redis 環境の構築

Redis 環境を別途構築してください。

### 14. Dapr の状態管理のコードを実装

Azure Container Apps は Dapr ランタイムを統合しています。そこで Dapr が提供する機能を素早く利用する事が可能です。
ここでは、Dapr が提供する機能のうちの一つ、状態管理の機能を試してみたいと思います。通常、マイクロサービスはステートレスで実装を行うよう推奨されていますが、必要に応じてアプリケーション無いでステートを持つ必要がある場合もあります。
このような時に、Dapr の状態管理機能を利用する事ができます。
また、Dapr を利用することで実際の状態の保存先を、アプリケーション・コードから引き離し柔軟に切り替えができるため、移植性の高い状態管理コードを実装できます。

Dapr の状態管理に関する詳細は [State management API reference](https://docs.dapr.io/reference/api/state_api/) をご参照ください。

ここでは、アプリケーションの状態を保存したり取得するための方法を簡単に紹介します。
Dapr はサイドカーを利用して、アプリケーションの状態を保存したり取得したりする API を提供しています。実際の状態の保存先は、[State stores](https://docs.dapr.io/reference/components-reference/supported-state-stores/) に記載されるように、様々な保存先に保存する事ができます。保存先の対象によってはトランザクションが非対応の場合もありますので、必要に応じて実際の保存先をご選択ください。

Dapr のサイドカーを利用すると、実際の保存先がどこかというのは意識せず、Dapr のサイドカーに対して HTTP リクエストを送信する事で、Dapr が実際の保存先にデータを永続化してくれます。
扱う事ができるデータは KEY, VALUE の組み合わせで管理を行います。

状態の保存

```text
POST http://localhost:<daprPort>/v1.0/state/<storename>
```

状態の取得

```text
GET http://localhost:<daprPort>/v1.0/state/<storename>/<key>
```

今回、上記のサイドカーに対して状態を保存したり取得するために、MicroProfile が提供する [REST Client](https://download.eclipse.org/microprofile/microprofile-rest-client-2.0/microprofile-rest-client-spec-2.0.html) の機能を利用します。

まず、REST Client のクラス `StateStoreService` を実装し `@RegisterRestClient` アノテーションを付加します。クラスに付加する `@Path` アノテーションで URL の指定を行います。ここでは `/v1.0/state` のパスにアクセスする事を指定しています。  
本クラスでは２つのメソッド `getData`, `setData` を定義し、それぞれ `@GET`, `@POST` アノテーションを付加しています。`<storename>` の箇所は、本アプリケーションでは `statestore` としています。この名前は、後ほど作成する `component.yaml` ファイル内で定義する名前と同じ名前を指定します。この実装で、`/v1.0/state/<storename>`, `/v1.0/state/<storename>/<key>` にアクセスする為の実装を行っています。  

```java
@Path("/v1.0/state")
@RegisterRestClient
public interface StateStoreService {

    @GET
    @Path("/statestore/{key}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> getData(@PathParam("key") String key);    
    
    @POST
    @Path("/statestore")
    @Produces(MediaType.APPLICATION_JSON)
    public Response  setData(ist<InputData> users);
}
```

URL のパス部分の実装は完了しましたが、どのサーバに接続するかは上記では記述していません。どのサーバに接続するかは `application.properties` ファイルに記述します。下記のように、REST Client の URL をパッケージ名を含むクラス名を記述し、接続先のホスト名を指定します。今回作成するアプリケーションの Dapr ポート番号は 3500 番で起動します（後述）。そこで、`http://localhost:3500` を指定してください。また、Swagger UI を閲覧できるように追加プロパティも設定しておきます。

```text
quarkus.rest-client."com.yoshio3.StateStoreService".url=http://localhost:3500

quarkus.smallrye-openapi.path=/swagger
quarkus.swagger-ui.always-include=true
```

REST Client の実装が完了したので、REST Client を呼び出す部分を実装します。今回は 2 つの REST エンドポイントを実装し、それらのエンドポイントが呼び出されたら、REST Client を呼び出すようにします。
`postData` メソッドでは引数に `List<InputData> users`を取っています。JSON 形式のデータを自動的に `List<InputData> users` 型にマーシャルしています。

```java
@Path("/")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class Main {

    @Inject
    @RestClient
    StateStoreService stateService;

    @GET
    @Path("/get/{key}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String>  getData(@PathParam("key") String key) {
        return stateService.getData(key);
    }

    @POST
    @Path("/post")
    @Produces(MediaType.APPLICATION_JSON)
    public Response postData(List<InputData> users) {
        Response res = stateService.setData(users);
        ...
    }
}
```

実装が終わったら、ソースコードをビルドし、コンテナ・レジストリにプッシュします。

```bash
export VERSION_TAG_OF_IMAGE=1.2
docker build -f Dockerfile -t tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE .
docker tag tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
docker push yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
```

### 15. Dapr のコンポーネント設定ファイルの作成

最後に、Dapr コンポーネントの設定を行います。このアプリケーションは状態のデータを Redis キャッシュに保存することにします。そこで Redis キャッシュへの接続情報を YAML に記述し、Dapr ランタイムはここで記述したサーバに接続しデータを管理します。`scopes` はどのアプリからこの設定が利用可能かを指定しています。

今回作成するアプリケーション名は、`quarkus-micro-service-dapr` に変更し　scopes に記載します。

```yml
componentType: state.redis
version: v1
metadata:
- name: redisHost
  value: joad.redis.cache.windows.net:6379
- name: redisPassword
  value: i53G***************************aADLHKE=
- name: actorStateStore
  value: "true"
scopes:
- quarkus-micro-service-dapr
```

環境変数に設定したアプリケーション名を変更しておいてください。

```bash
export APPLICATION_NAME=quarkus-micro-service-dapr
```

上記の YAML ファイルを `components.yaml` というファイル名に記載し保存します。そして `az containerapp env dapr-component set` コマンドで上記のコンポーネントを `statestore` という名前で登録します。

```azurecli
az containerapp env dapr-component set \
    --name $CONTAINERAPPS_ENVIRONMENT --resource-group $RESOURCE_GROUP \
    --dapr-component-name statestore \
    --yaml components.yaml
```

> 注意
> `statestore` という名前は `<storename>` の部分で指定する名前になります。

```text
POST http://localhost:<daprPort>/v1.0/state/<storename>
GET http://localhost:<daprPort>/v1.0/state/<storename>/<key>
```

名前を変更する場合は、REST Client の `@Path` 部分も変更してください。

```java
public interface StateStoreService {

    @GET
    @Path("/statestore/{key}")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> getData(@PathParam("key") String key);    
    
    @POST
    @Path("/statestore")
    @Produces(MediaType.APPLICATION_JSON)
    public Response  setData(ist<InputData> users);
}
```

### 16. Azure Container App インスタンスの作成

Dapr コンポーネントを登録したので、最後に Dapr に対応したアプリケーションを作成します。

```azurecli
az containerapp create \
  --name $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE \
  --target-port 8080 \
  --ingress 'external' \
  --query 'configuration.ingress.fqdn' \
  --cpu 1 --memory 2.0Gi \
  --min-replicas 1 --max-replicas 4 \
  --enable-dapr \
  --dapr-app-port 3500 \
  --dapr-app-id $APPLICATION_NAME 
```

正常にデプロイが完了したのち、動作確認を行います。
本アプリケーションでは Swagger UI を利用できるように設定しています。そこでブラウザから下記の URL にアクセスすると Swagger UI 経由で RESTful エンドポイントにアクセスができます。

```text
https://quarkus-micro-service.livelyriver-edab7c68.eastus.azurecontainerapps.io/q/swagger-ui
```

また、curl コマンドで直接アクセスをして状態データを保存する事ができます。

```bash
curl -X 'POST' \
  'https://quarkus-micro-service.livelyriver-edab7c68.eastus.azurecontainerapps.io/post' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '[
  {
    "key": "terada",
    "value": {
     "firstname": "Yoshio",
     "lastname" : "Terada",
     "email" : "yoshio.terada@microsoft.com",
     "address" : "Shinagawa"
    }
  }
]'
```

登録したデータは下記のように KEY を指定して取得する事が可能です。

```bash
curl -X 'GET' \
  'https://quarkus-micro-service.livelyriver-edab7c68.eastus.azurecontainerapps.io/get/terada' \
  -H 'accept: application/json'
```

### 17. Azure Container App インスタンスの更新

ソースコードを修正しアプリケーションを更新する場合は、下記のように再度コンテナ・イメージを作成します。

```bash
export VERSION_TAG_OF_IMAGE=1.3
docker build -f Dockerfile -t tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE .
docker tag tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
docker push yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
```

コンテナ・イメージをレジストリにプッシュした後、`az containerapp update` コマンドでアプリケーションのコンテナ・イメージを更新します。

```azurecli
az containerapp update \
  --name  $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP \
  --image yoshio.azurecr.io/tyoshio2002/quarkus-sample:$VERSION_TAG_OF_IMAGE
```

## 備考

[Dapr における Azure Redis の設定に関する注意点](https://docs.dapr.io/reference/components-reference/supported-state-stores/setup-redis/#configuration) に下記の記載があります。ご注意ください。

```text
Open this link to start the Azure Cache for Redis creation flow. Log in if necessary.
Fill out necessary information and check the “Unblock port 6379” box, 
which will allow us to persist state without SSL.
Click “Create” to kickoff deployment of your Redis instance.

Once your instance is created, you’ll need to grab the Host name (FQDN) and your access key.
for the Host name navigate to the resources “Overview” and copy “Host name”
for your access key navigate to “Access Keys” under “Settings” and copy your key.
Finally, we need to add our key and our host to a redis.yaml file that Dapr can apply to our cluster. 
If you’re running a sample, you’ll add the host and key to the provided redis.yaml. 
If you’re creating a project from the ground up, you’ll create a redis.yaml file 
as specified in Configuration. Set the redisHost key to 
[HOST NAME FROM PREVIOUS STEP]:6379 and the redisPassword key to the key you copied 
in step 4. 
Note: In a production-grade application, follow secret management instructions to 
securely manage your secrets.

NOTE: Dapr pub/sub uses Redis Streams that was introduced by Redis 5.0, 
which isn’t currently available on Azure Managed Redis Cache. 
Consequently, you can use Azure Managed Redis Cache only for state persistence.
```
