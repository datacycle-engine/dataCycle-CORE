# frozen_string_literal: true

namespace :dc do
  namespace :cache do
    desc 'basic cache warmup (for api_v4)'
    task warm_up: :environment do
      session = ActionDispatch::Integration::Session.new(Rails.application)
      api_stored_filter = DataCycleCore::StoredFilter.where(api: true)
      api_token = DataCycleCore::User.find_by(email: 'admin@datacycle.at').access_token
      api_stored_filter.each do |filter|
        puts "loading endpoint: #{filter.name} #{filter.id} (page 1)"
        session.get("/api/v4/endpoints/#{filter.id}?token=#{api_token}")
        json_data = JSON.parse(session.response.body)
        pages = json_data.dig('meta', 'pages').to_i
        (2..pages).to_a.each do |page|
          break if page > 10
          puts "loading endpoint: #{filter.name} #{filter.id} (page #{page})"
          session.get("/api/v4/endpoints/#{filter.id}?token=#{api_token}&page[number]=#{page}")
        end
      end
    end
  end
end
