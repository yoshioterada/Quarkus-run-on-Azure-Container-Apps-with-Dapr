package com.yoshio3;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
public class MainTest {

    @Test
    public void testHelloEndpoint() {
        given()
          .when().get("/svc")
          .then()
             .statusCode(200)
             .body(is("Hello RESTEasy"));
    }

}