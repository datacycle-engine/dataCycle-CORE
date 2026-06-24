# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsExportController < ApiBaseController
        after_action :check_job_status, only: [:show]

        def show
          @external_system = DataCycleCore::ExternalSystem
            .by_names_identifiers_or_ids(permitted_params[:external_system_id])
            .first!
          @ids = permitted_params[:ids].to_s.split(',').map(&:strip)
          @contents = DataCycleCore::Thing.where(id: @ids)

          transformations = @external_system.export_config['transformations']&.safe_constantize
          raise ActiveRecord::RecordNotFound, 'No export transformations found for given external system!' if transformations.nil?

          render_params = transformations.method(:render).parameters

          if render_params.first&.last == :contents
            render transformations.format => transformations.render(@contents, @external_system)
          else
            render transformations.format => transformations.render(@contents.first, @external_system)
          end
        end

        def permitted_params
          @permitted_params ||= params.permit(:external_system_id, :ids)
        end

        private

        def check_job_status
          refresh_strategy = @external_system.export_config.dig('refresh', 'strategy')
          return if refresh_strategy.blank?
          return unless Array.wrap(refresh_strategy.safe_constantize.hooks).include?(:after_show)

          @contents.each do |content|
            content.allowed_webhooks = [@external_system.name]
            content.execute_webhooks('refresh')
          end
        end
      end
    end
  end
end
