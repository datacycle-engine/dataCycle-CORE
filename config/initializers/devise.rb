Devise.setup do |config|
  config.router_name = :data_cycle_core #"DataCycleCore::User"
  config.parent_controller = 'DataCycleCore::ApplicationController'
  config.mailer_sender = 'webmaster@pixelpoint.at'
  require 'devise/orm/active_record'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 11
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # ==> Configuration for :saml_authenticatable

  # Create user if the user does not exist. (Default is false)
  config.saml_create_user = true

  # Update the attributes of the user after a successful login. (Default is false)
  config.saml_update_user = true

  # Set the default user key. The user will be looked up by this key. Make
  # sure that the Authentication Response includes the attribute.
  config.saml_default_user_key = :email

  # Optional. This stores the session index defined by the IDP during login.  If provided it will be used as a salt
  # for the user's session to facilitate an IDP initiated logout request.
  config.saml_session_index_key = :session_index

  # You can set this value to use Subject or SAML assertation as info to which email will be compared.
  # If you don't set it then email will be extracted from SAML assertation attributes.
  config.saml_use_subject = false

  # You can support multiple IdPs by setting this value to a class that implements a #settings method which takes
  # an IdP entity id as an argument and returns a hash of idp settings for the corresponding IdP.
  config.idp_settings_adapter = nil

  # You provide you own method to find the idp_entity_id in a SAML message in the case of multiple IdPs
  # by setting this to a custom reader class, or use the default.
  # config.idp_entity_id_reader = DeviseSamlAuthenticatable::DefaultIdpEntityIdReader

  # You can set a handler object that takes the response for a failed SAML request and the strategy,
  # and implements a #handle method. This method can then redirect the user, return error messages, etc.
  # config.saml_failed_callback = nil

  # Configure with your SAML settings (see [ruby-saml][] for more information).
  config.saml_configure do |settings|
    settings.assertion_consumer_service_url     = "http://localhost:3000/users/saml/auth"
    settings.assertion_consumer_service_binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
    settings.issuer =                         "http://adfs.austria.info/adfs/services/trust"
    settings.name_identifier_format =         "urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    settings.idp_sso_target_url =             "https://adfs.austria.info/adfs/ls/"
    settings.idp_cert_fingerprint_algorithm = XMLSecurity::Document::SHA256
    settings.security[:digest_method]    = XMLSecurity::Document::SHA256
    settings.security[:signature_method] = XMLSecurity::Document::SHA256

    settings.security[:embed_sign]        = false

    # settings.assertion_consumer_service_url     = "http://localhost:3000/users/saml/auth"
    # settings.assertion_consumer_service_binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
    # settings.name_identifier_format             = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" #"urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    # settings.issuer                             = "http://localhost:3000/users/saml/metadata"
    # settings.authn_context                      = ""
    # settings.idp_slo_target_url                 = "https://adfs.austria.info/adfs/ls/"
    # settings.idp_sso_target_url                 = "https://adfs.austria.info/adfs/ls/"
    settings.idp_cert                           = <<-CERT.chomp
-----BEGIN CERTIFICATE-----
MIIC3jCCAcagAwIBAgIQds2c3D+//JRPLwRR4y8MKzANBgkqhkiG9w0BAQsFADAr
MSkwJwYDVQQDEyBBREZTIFNpZ25pbmcgLSBhZGZzLmF1c3RyaWEuaW5mbzAeFw0x
NjA3MjkxMzAxNDRaFw0xNzA3MjkxMzAxNDRaMCsxKTAnBgNVBAMTIEFERlMgU2ln
bmluZyAtIGFkZnMuYXVzdHJpYS5pbmZvMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAqIHbCYCOUG2x6g7W+kS0YeDAshlYCpoDRkLZGfDHxzupEVfVipDs
CXtyXcfk6hlUvwgYk9DwwPHC+Ryaq0/kXvb3dyVtzVS4dVv1nN5/tRqCfbhFD+7r
HgGFAwoletrkp/Aq55JI20iIcimadmY9EzfSPO1gUfEVnzEJwGH4NSncFLkePcME
Kqdzc6CID35cVRTQFIahAiFgsZSi6oom8WQQbG4oauvt51q3McmNDqZG8XiQJMqr
9vEmEhdXLESHBDtrb49p1Xg7Le9H/kz+pU/RYpljSxeIeflo867IjFarAJUbh4y4
7JVoq7+Tfhd+6IOTCm3TdiSqpH4vdud6kwIDAQABMA0GCSqGSIb3DQEBCwUAA4IB
AQCCFrvAaVbJU+h4qmKYdaAVINVWL5wsWTCE8gbdlB4+nUqnJg5GMBXG91Oc6a/8
Rx7a8XlL07BTy36bQHvUHlWKz7Hh7kCD8b0DfjHg3eFY/U/aWLBIQXF1u5quNOvs
R+zu0JDPddBMXjWrXLwVateAJ8myQNKueiiNrVkmzI6XjvvedDwVoc26M4UtrxJl
ndfsh+JRF4kOO8hfUdAlIfvAh2Y/TzhalT3wboYfqi0hBt1Y30s5N1M9jswWWtC9
5WnQPJmK3izpQji1HxjTeCAjPa5GVPYN+Z6k7nWuyQ6EkRuHJ0q0rv2EdP4TSqQ5
ATLpPVwxwPGrLL+MDkkDzDwL
-----END CERTIFICATE-----
    CERT
  end


end
