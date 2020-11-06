# frozen_string_literal: true

namespace :dc do
  namespace :statistics do
    desc 'output template names and frequency in Thing and Thing::History'
    task template_statistics: :environment do
      statistics, history = DataCycleCore::MasterData::ImportTemplates.template_statistics
      puts "#{'Things(template)'.ljust(40)} |      count | content_type"
      puts '-' * 69
      statistics.sort { |a, b| a[1][0] <=> b[1][0] }.each do |template, count|
        puts "#{template.to_s.ljust(40)} | #{count[1].to_s.rjust(10)} | #{count[0]}"
      end
      puts
      puts "#{'Things History(template)'.ljust(40)} |      count | content_type"
      puts '-' * 69
      history.sort { |a, b| a[1][0] <=> b[1][0] }.each do |template, count|
        puts "#{template.to_s.ljust(40)} | #{count[1].to_s.rjust(10)} | #{count[0]}"
      end
    end
  end
end
