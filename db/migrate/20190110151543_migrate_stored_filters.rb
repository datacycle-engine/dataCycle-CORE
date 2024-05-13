# frozen_string_literal: true

class MigrateStoredFilters < ActiveRecord::Migration[5.1]
  def up
    # return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'

    # DataCycleCore::StoredFilter.find_each do |filter|
    #   order_hash = filter.parameters&.select { |parameter| parameter['t'] == 'order' }&.first || []
    #   next if order_hash.blank?

    #   order_string = order_hash.dig('v')
    #   if order_string.size > 50
    #     new_string = order_string
    #       .gsub(/\Aboost \* \(/, 'things.boost * (')
    #       .gsub(' updated_at DESC', ' things.updated_at DESC')
    #       .gsub(/ searches.updated_at DESC/, ' things.updated_at DESC')
    #       .gsub(' similarity(classification_string, ', ' similarity(searches.classification_string, ')
    #       .gsub(' similarity(headline, ', ' similarity(searches.headline, ')
    #       .gsub(' ts_rank_cd(words, ', ' ts_rank_cd(searches.words, ')
    #       .gsub(' similarity(full_text, ', ' similarity(searches.full_text, ')
    #   else
    #     new_string = 'things.boost DESC, things.updated_at DESC'
    #   end

    #   parameters = filter.parameters.without(order_hash).push({ 't' => 'order', 'v' => new_string })
    #   filter.parameters = parameters
    #   filter.save(touch: false)
    # end
  end
end
