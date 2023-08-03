# frozen_string_literal: true

class FixDuplicatePotentialActionForEvents < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore')

    return if external_source.blank?

    contents = DataCycleCore::Thing.includes(:external_source).where(template_name: 'Event', external_source_id: external_source.id)
    progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

    contents.find_each do |content|
      I18n.with_locale(content.first_available_locale) do
        next if content.potential_action.blank? || content.potential_action.count { |c| c.name == 'potential_action' } <= 1

        data_hash = {
          'potential_action' => content.attribute_to_h('potential_action').reject { |c| c['name'] == 'potential_action' && c['external_key'].blank? }
        }

        content.set_data_hash(data_hash: data_hash, prevent_history: true)
      rescue StandardError
        nil
      ensure
        progressbar.increment
      end
    end
  end

  def down
  end
end
