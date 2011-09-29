##! This script can be used to generate notices when X.509 certificates over
##! SSL/TLS are expired or going to expire based on the date and time values
##! stored within the certificate.  Notices will be suppressed for 1 day
##! by default.

@load base/protocols/ssl
@load base/frameworks/notice
@load base/utils/directions-and-hosts

module SSL;

export {
	redef enum Notice::Type += {
		## Indicates that a certificate's NotValidAfter date has lapsed and
		## the certificate is now invalid.
		Certificate_Expired,
		## Indicates that a certificate is going to expire within 
		## :bro:id:`SSL::notify_when_cert_expiring_in`.
		Certificate_Expires_Soon,
		## Indicates that a certificate's NotValidBefore date is future dated.
		Certificate_Not_Valid_Yet,
	};
	
	## Which hosts you would like to be notified about which have certificates
	## that are going to be expiring soon.
	## Choices are: LOCAL_HOSTS, REMOTE_HOSTS, ALL_HOSTS, NO_HOSTS
	const notify_certs_expiration = LOCAL_HOSTS &redef;
	
	## The time before a certificate is going to expire that you would like to
	## start receiving notices.
	const notify_when_cert_expiring_in = 30days &redef;
}

redef Notice::type_suppression_intervals += { 
	[[Certificate_Expired, Certificate_Expires_Soon, Certificate_Not_Valid_Yet]] = 1day
};

event x509_certificate(c: connection, cert: X509, is_server: bool, chain_idx: count, chain_len: count, der_cert: string) &priority=5
	{
	# If this isn't the host cert or we aren't interested in the server, just return.
	if ( chain_idx != 0 || ! addr_matches_host(c$id$resp_h, notify_certs_expiration) )
		return;
	
	if ( cert$not_valid_before > network_time() )
		NOTICE([$note=Certificate_Not_Valid_Yet,
		        $conn=c, $suppress_for=1day,
		        $msg=fmt("Certificate %s isn't valid until %T", cert$subject, cert$not_valid_before),
		        $identifier=fmt("%s:%d-%s", c$id$resp_h, c$id$resp_p, md5_hash(der_cert))]);
	
	else if ( cert$not_valid_after < network_time() )
		NOTICE([$note=Certificate_Expired,
		        $conn=c, $suppress_for=1day,
		        $msg=fmt("Certificate %s expired at %T", cert$subject, cert$not_valid_after),
		        $identifier=fmt("%s:%d-%s", c$id$resp_h, c$id$resp_p, md5_hash(der_cert))]);
	
	else if ( cert$not_valid_after - notify_when_cert_expiring_in < network_time() )
		NOTICE([$note=Certificate_Expires_Soon,
		        $msg=fmt("Certificate %s is going to expire at %T", cert$subject, cert$not_valid_after),
		        $conn=c, $suppress_for=1day,
		        $identifier=fmt("%s:%d-%s", c$id$resp_h, c$id$resp_p, md5_hash(der_cert))]);
	}
