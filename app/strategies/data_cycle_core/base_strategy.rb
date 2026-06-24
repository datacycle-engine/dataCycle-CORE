# frozen_string_literal: true

module DataCycleCore
  class BaseStrategy < Warden::Strategies::Base
    def valid_strategy?
      params[:warden_strategy].blank? || warden_strategy?
    end

    def warden_strategy?
      params[:warden_strategy] == self.class.name.demodulize.underscore.delete_suffix('_strategy')
    end

    private

    def validate(resource, &) # rubocop:disable Naming/PredicateMethod
      result = resource&.valid_for_authentication?(&)

      if result
        true
      else
        fail!(resource.unauthenticated_message) if resource
        false
      end
    end
  end
end
