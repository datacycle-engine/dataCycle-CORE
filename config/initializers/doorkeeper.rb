# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  base_controller 'DataCycleCore::ApplicationController'
  default_scopes :public
  optional_scopes :openid, :profile, :email, :roles, :groups

  resource_owner_authenticator do
    current_user ||= warden.authenticate!(scope: :user)
    authorize!(:authenticate_with, :oauth) if current_user
    current_user
  end

  authorize_resource_owner_for_client do |client, resource_owner|
    next true unless client.name == 'Grafana'

    resource_owner.can?(:show, :grafana_dashboards)
  end

  admin_authenticator do |_routes|
    current_user ||= warden.authenticate!(scope: :user)
    authorize!(:manage, Doorkeeper::Application) if current_user
    current_user
  end

  grant_flows ['authorization_code', 'implicit_oidc']

  skip_authorization do |_resource_owner, client|
    client.name == 'Grafana'
  end
end

Doorkeeper::OpenidConnect.configure do
  issuer 'dataCycle'

  signing_key(
    if (path = ENV['OPENID_CONNECT_PRIVATE_KEY_PEM_FILE']).present? && File.exist?(path)
      File.read(path)
    else
      ENV['OPENID_CONNECT_PRIVATE_KEY_PEM']
    end
  )

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    DataCycleCore::User.find_by(id: access_token.resource_owner_id)
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # sign_out resource_owner
    # redirect_to new_user_session_url
  end

  # Depending on your configuration, a DoubleRenderError could be raised
  # if render/redirect_to is called at some point before this callback is executed.
  # To avoid the DoubleRenderError, you could add these two lines at the beginning
  #  of this callback: (Reference: https://github.com/rails/rails/issues/25106)
  #   self.response_body = nil
  #   @_response_body = nil
  select_account_for_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # redirect_to account_select_url
  end

  subject do |resource_owner, _application|
    resource_owner.id
  end

  auth_time_from_resource_owner(&:current_sign_in_at)

  claims do
    claim :email do |resource_owner, _scopes, _access_token|
      resource_owner.email
    end

    claim :email_verified do |resource_owner, _scopes, _access_token|
      resource_owner.respond_to?(:confirmed?) && resource_owner.confirmed?
    end

    claim :name, scope: :profile do |resource_owner, _scopes, _access_token|
      resource_owner.full_name
    end

    claim :roles, scope: :roles do |resource_owner, _scopes, _access_token|
      Array.wrap(resource_owner.role_name)
    end

    claim :groups, scope: :groups do |resource_owner, _scopes, _access_token|
      resource_owner.group_names
    end
  end
end
