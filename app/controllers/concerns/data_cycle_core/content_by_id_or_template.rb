# frozen_string_literal: true

module DataCycleCore
  module ContentByIdOrTemplate
    extend ActiveSupport::Concern

    private

    def content_by_id_or_template_params
      params.permit(:content_id, :content_template_name, { content_template: {} })
    end

    def content_by_id_or_template
      content = DataCycleCore::Thing.find_by(id: content_by_id_or_template_params[:content_id]) if content_by_id_or_template_params[:content_id].present?

      return content unless content.nil?

      content = DataCycleCore::Thing.new(template_name: content_by_id_or_template_params[:content_template_name], created_by: current_user, id: SecureRandom.uuid) if content_by_id_or_template_params[:content_template_name].present?

      return content unless content.nil?

      thing_template = resolve_params(content_by_id_or_template_params[:content_template])&.dig(:thing_template)

      DataCycleCore::Thing.new(thing_template:, id: content_by_id_or_template_params[:content_id].presence || SecureRandom.uuid) if thing_template.present?
    end
  end
end
