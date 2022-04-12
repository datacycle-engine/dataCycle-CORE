vcl 4.0;

backend static {
    .host = "imgproxy";
    .port = "9000";
}
sub vcl_recv {
    unset req.http.cookie;
    unset req.http.Accept-Language;
    if (req.method == "BAN") {
        if (!req.http.x-invalidate-pattern) {
            return (purge);
        }
        ban("obj.http.x-url ~ " + req.http.x-invalidate-pattern
            + " && obj.http.x-host == " + req.http.host);
        return (synth(200,"Ban added"));
    }
}

sub vcl_backend_response {
	# Don't cache 404 responses
	if ( beresp.status == 404 ) {
		set beresp.ttl = 120s;
		set beresp.uncacheable = true;
		return (deliver);
	}
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;
    set beresp.http.cache-control = "public, max-age=31536000";
    set beresp.ttl = 31536000s;
    unset beresp.http.expires;
}

sub vcl_deliver {
    unset resp.http.x-url;
    unset resp.http.x-host;
}