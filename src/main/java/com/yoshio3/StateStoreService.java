package com.yoshio3;

import java.util.List;
import java.util.Map;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import com.yoshio3.model.InputData;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

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
    public Response  setData(List<InputData> users);
}
