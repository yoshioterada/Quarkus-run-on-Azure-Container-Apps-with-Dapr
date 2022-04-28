package com.yoshio3;

import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

import org.eclipse.microprofile.rest.client.inject.RestClient;

@Path("/")
public class Main {

    @Inject
    @RestClient
    MyRemoteService remoteSvc;

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    @Path("/serviceB")
    public BackData invokeBackService() {
        return remoteSvc.invokeBackService();
    }
}