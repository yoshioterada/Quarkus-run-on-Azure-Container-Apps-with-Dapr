package com.yoshio3;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/")
public class Main {

    @GET
    @Path("/hello-service")
    @Produces(MediaType.APPLICATION_JSON)
    public BackData hello() {
        BackData data = new BackData("back result","This is Backend Service");
        return data;
    }
}