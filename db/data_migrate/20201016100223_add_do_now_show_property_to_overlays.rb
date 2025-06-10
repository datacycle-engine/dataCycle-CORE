# frozen_string_literal: true

class AddDoNowShowPropertyToOverlays < ActiveRecord::Migration[5.2]
  def up
    thing_ids = DataCycleCore::ContentContent.where(relation_a: 'overlay').pluck(:content_b_id)
    DataCycleCore::Thing::Translation.where(thing_id: thing_ids).find_each do |i|
      i.content = i.content.nil? ? { dummy: 'do_not_show' } : i.content.merge({ dummy: 'do_not_show' })
      i.save
    end
  end

  def down
    thing_ids = DataCycleCore::ContentContent.where(relation_a: 'overlay').pluck(:content_b_id)
    DataCycleCore::Thing::Translation.where(thing_id: thing_ids).find_each do |i|
      i.content = i.content&.except('dummy')
      i.save
    end
  end
end
