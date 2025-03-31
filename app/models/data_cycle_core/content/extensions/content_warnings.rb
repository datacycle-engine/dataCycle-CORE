# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ContentWarnings
        def content_warning_messages(context = nil)
          @content_warning_messages ||= {
            hard: [],
            soft: [],
            highlight: []
          }.tap do |w|
            DataCycleCore.content_warnings.slice('Common', template_name).presence&.each do |key, value|
              value.presence&.each do |k, v|
                warning_class = DataCycleCore::ModuleService.safe_load_module(v[:module] || key.classify, 'Warning')

                next unless warning_class.try(k, v.except(:active, :hard, :module), self, context)

                key = v[:hard] ? :hard : :soft
                w[:highlight] << key if v[:highlight] && w[:highlight].exclude?(key)

                w[key].push(warning_class.try("#{k}_message", k, self, context) || warning_class.message(k, self, context))
              end
            end
          end
        end

        def content_warnings(context = nil)
          content_warning_messages(context).values.flatten
        end

        def content_warnings?(context = nil)
          content_warning_messages(context).values.any?(&:present?)
        end

        def hard_content_warnings?(context = nil)
          content_warning_messages(context)[:hard].present?
        end

        def soft_content_warnings?(context = nil)
          content_warning_messages(context)[:soft].present?
        end

        def highlight_soft_content_warnings?(context = nil)
          content_warning_messages(context)[:highlight].include?(:soft)
        end

        def highlight_hard_content_warnings?(context = nil)
          content_warning_messages(context)[:highlight].include?(:hard)
        end
      end
    end
  end
end
