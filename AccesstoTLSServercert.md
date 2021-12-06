# Access to TLS Server certificate info

The WebView/CoreView WPF API describes how to process requests for a client certificate but there is no mention of 
a corresponding server certificate interface.

What I want is access to the TLS context for each connection, in particular the certificate chain and end entity 
certificate. I would ideally want to be able to perform additional checking on the certificate at this stage.

If this API does not exist, the alternative would seem to be to intercept the http/https URI resolution requests 
and process them with the .NET WebClient API which has the necessary hooks.
