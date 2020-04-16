# frozen_string_literal: true

module IceCube
  class Railtie < Rails::Railtie
    initializer 'ice_cube_i18n', before: 'rails-i18n' do
      IceCube::I18n.backend
    end
  end
end
