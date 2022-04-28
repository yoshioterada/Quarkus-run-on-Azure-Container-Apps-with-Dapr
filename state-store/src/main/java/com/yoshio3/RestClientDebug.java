package com.yoshio3;

import java.util.List;
import java.util.Map;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@Path("/v1.0")
@RegisterRestClient
public interface RestClientDebug {

    @GET
    @Path("/invoke/{applicationID}/method/hello")
    public Response invokeService(@PathParam("applicationID") String key);    

    @GET
    @Path("/healthz")
    public Response healthCheck();    

}
