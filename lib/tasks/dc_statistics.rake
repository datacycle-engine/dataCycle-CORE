# frozen_string_literal: true

namespace :dc do
  namespace :statistics do
    desc 'output template names and frequency in Thing and Thing::History'
    task template_statistics: :environment do
      statistics, history = DataCycleCore::MasterData::ImportTemplates.template_statistics
      puts "#{'Things(template)'.ljust(40)} |      count"
      puts '-' * 53
      statistics.each do |template, count|
        puts "#{template.to_s.ljust(40)} | #{count.to_s.rjust(10)} "
      end
      puts
      puts "#{'Things History(template)'.ljust(40)} |      count"
      puts '-' * 53
      history.each do |template, count|
        puts "#{template.to_s.ljust(40)} | #{count.to_s.rjust(10)} "
      end
    end
  end
end
