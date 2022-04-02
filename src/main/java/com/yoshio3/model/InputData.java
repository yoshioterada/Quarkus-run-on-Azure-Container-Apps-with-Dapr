package com.yoshio3.model;

import java.io.Serializable;
import java.util.Map;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;

// Input Data is look like follows
// You can refer the detail specification of the state store as following URL.
// https://docs.dapr.io/reference/api/state_api/
//
// curl -v -X 'POST' \
//   'https://DAPR_INSTANCE_NAME.eastus.azurecontainerapps.io/post' \
//   -H 'accept: */*' \
//   -H 'Content-Type: application/json' \
//   -d '[
//   {
//     "key": "terada2",
//     "value": {
// 	"firstname": "Yoshio",
// 	"lastname" : "Terada",
// 	"email" : "yoshio.terada@microsoft.com",
// 	"address" : "Yokohama"
//     }
//   }
// ]'

@JsonPropertyOrder({"key", "value"})
public class InputData implements Serializable{

    public String key;
    public Map<String, String> value;

    public InputData(){
    }

    @JsonCreator
    public InputData(@JsonProperty("key") final String key,
            @JsonProperty("value") final Map<String, String> value) {
        this.key = key;
        this.value = value;
    }


    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    public Map<String, String> getValue() {
        return value;
    }

    public void setValue(Map<String, String> value) {
        this.value = value;
    }
}
