# frozen_string_literal: true

class ChangeContentLocationToLocationForEvents < ActiveRecord::Migration[5.2]
  def up
    DataCycleCore::ContentContent.includes(:content_a).where(relation_a: 'content_location', things: { template_name: ['Event', 'EventOverlay', 'SubEvent'] }).update_all(relation_a: 'location')
    DataCycleCore::ContentContent::History.includes(:content_a_history).where(relation_a: 'content_location', thing_histories: { template_name: ['Event', 'EventOverlay', 'SubEvent'] }).update_all(relation_a: 'location')
  end

  def down
    DataCycleCore::ContentContent.includes(:content_a).where(relation_a: 'location', things: { template_name: ['Event', 'EventOverlay', 'SubEvent'] }).update_all(relation_a: 'content_location')
    DataCycleCore::ContentContent::History.includes(:content_a_history).where(relation_a: 'location', thing_histories: { template_name: ['Event', 'EventOverlay', 'SubEvent'] }).update_all(relation_a: 'content_location')
  end
end
