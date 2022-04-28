# Dapr の状態管理を利用する - Quarkus on Azure Container Apps

## はじめに


### 1. Redis 環境の構築

Redis 環境を別途構築してください。

### 2. Dapr の状態管理のコードを実装

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

### 3. Dapr のコンポーネント設定ファイルの作成

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

### 4. Azure Container App インスタンスの作成

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
  --dapr-app-port 8080 \
  --dapr-app-id $APPLICATION_NAME 
```

正常にデプロイが完了したのち、動作確認を行います。
本アプリケーションでは Swagger UI を利用できるように設定しています。そこでブラウザから下記の URL にアクセスすると Swagger UI 経由で RESTful エンドポイントにアクセスができます。

```text
https://quarkus-micro-service-dapr.blackfield-e0bd3058.eastus.azurecontainerapps.io//q/swagger-ui
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

### 5. Azure Container App インスタンスの更新

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
