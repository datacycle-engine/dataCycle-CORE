module DataCycleCore
  module MasterData
    module Validators
      class BasicValidator
        attr_reader :error

        def initialize(data, template, template_key = '')
          @error = { error: {}, warning: {} }
          @template_key = template_key
          validate(data, template)
        end

        def validate(data, template)
        end

        def merge_errors(error_hash)
          @error.each_key do |key|
            @error[key].merge!(error_hash[key]) if error_hash.key?(key)
          end
        end

        def uuid?(data)
          data_clean = data.squish.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data_clean.length == 36 && !(data_clean =~ uuid).nil?
          (@error[:error][@template_key] ||= []) << I18n.t(:uuid, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) unless check_uuid
          check_uuid
        end
      end
    end
  end
end
