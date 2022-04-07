package com.yoshio3;

import java.util.List;
import java.util.Map;
import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import com.yoshio3.model.InputData;

import org.eclipse.microprofile.rest.client.inject.RestClient;

@Path("/")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class Main {

    @GET
    @Path("/hello")
    public String hello() {
        return "Hello from GitHub Action";
    }

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

        int status = res.getStatus();
        Response response;
        switch(status){
            case 204 : response = Response.ok("{\"message :\" \"State saved\"}").build();
            break;
            case 400 : response = Response.status(400).entity("{\"message :\" \"State store is missing or misconfigured or malformed request\"}").build();
            break;
            case 500 : response = Response.status(500).entity("{\"message :\" \"Failed to save state\"}").build();
            break;
            default:
            response = Response.status(500).entity("{\"message :\" \"Some problem happen\"}").build();
        }
        return response;
    }
}
