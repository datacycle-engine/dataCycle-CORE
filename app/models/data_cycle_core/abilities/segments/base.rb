# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class Base
        # dynamic scopes or permissions have to be implemented as instance methods, as user and session are nil during initialization (can't be used in initialize method)

        attr_reader :user, :session

        MODEL_NAME_MAPPINGS = {
          users: User,
          user_groups: UserGroup,
          subscriptions: Subscription,
          things: Thing,
          collection: WatchList
        }.freeze

        def to_descriptions
          return unless visible?

          translated_subjects.map do |subject, translated_subject|
            {
              permission: to_permission(subject:, translated_subject:),
              restrictions: to_restrictions(subject:, translated_subject:),
              segment: self
            }
          end
        end

        def to_h
          instance_variables.index_with { |v| instance_variable_get(v) }
        end

        delegate :hash, to: :to_h

        def eql?(other)
          self == other
        end

        def ==(other)
          self.class == other.class && to_h == other.to_h
        end

        def locale
          user&.ui_locale || DataCycleCore.ui_locales.first
        end

        def translated_subjects
          Array.wrap(try(:subject)).to_h do |v|
            value = MODEL_NAME_MAPPINGS[v] || v

            case value
            when Symbol
              [value, I18n.t("abilities.model_names.#{value}", locale:)]
            else
              [value, value.model_name.human(locale:, count: 2)]
            end
          end
        end

        def i18n_key
          self.class.name.demodulize.underscore
        end

        private

        def visible?
          true
        end

        def to_permission(translated_subject:, **)
          translated_subject
        end

        def to_restrictions(**)
          to_restriction
        end

        def to_restriction(**)
          return unless I18n.exists?("abilities.restrictions.#{i18n_key}", locale:, **)

          I18n.t("abilities.restrictions.#{i18n_key}", locale:, **)
        end
      end
    end
  end
end
