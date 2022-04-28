package com.yoshio3;

import java.io.IOException;
import javax.ws.rs.client.ClientRequestContext;
import javax.ws.rs.client.ClientRequestFilter;
import javax.ws.rs.client.ClientResponseContext;
import javax.ws.rs.client.ClientResponseFilter;
import org.jboss.logging.Logger;

public class RestClientRequestFilter implements ClientRequestFilter, ClientResponseFilter{

    private static final Logger LOG = Logger.getLogger(RestClientRequestFilter.class);    
    @Override
    public void filter(ClientRequestContext requestContext) throws IOException {
        LOG.debug("-------- REQUEST URL -----" + requestContext.getUri().toString());
        requestContext.getHeaders().forEach((key, value) -> value.stream()
                .map(k -> (String)k)
                .forEach(v -> {LOG.debug("REQUEST HEADER NAME: " + key + "\t HEADER VALUE: " + v);}));
    }

    @Override
    public void filter(ClientRequestContext requestContext, ClientResponseContext responseContext) throws IOException {
        LOG.debug("----- Media Type --- " + responseContext.getMediaType().toString());
        LOG.debug("----- Status Code --- " +responseContext.getStatus());
        responseContext.getHeaders().forEach((key, value) -> value.stream()
            .map(k -> (String)k)
            .forEach(v -> {LOG.debug("RESPONSE HEADER NAME: " + key + "\t HEADER VALUE: " + v);}));
    }
}
