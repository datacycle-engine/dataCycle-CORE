# frozen_string_literal: true

namespace :dc do
  namespace :performance do
    desc 'override some files in project from core templates'
    task compare_filter_strategies: :environment do
      strategies = [:filter_exists]
      base_strategy = strategies.first
      repetitions = 3
      # endpoints = DataCycleCore::StoredFilter.where('collections.parameters::text ILIKE ?', '%union_filter_ids%').named.limit(100).order(name: :asc)
      endpoints = DataCycleCore::StoredFilter.named.order(name: :asc)

      puts "Comparing filter strategies for #{endpoints.size} endpoints"
      puts '---'

      CSV.open(Rails.public_path.join('filter_strategies.csv'), 'wb') do |csv|
        endpoints.each do |endpoint|
          puts "Endpoint: #{endpoint.name} (##{endpoint.id})"
          csv << ['Endpoint', endpoint.name, endpoint.id]

          strategy_times = {}
          base_counts = {}
          strategies.each do |strategy|
            # warm up
            ids = endpoint.things.page(1).reload.map(&:id)
            count = endpoint.things.count

            if strategy == base_strategy
              base_counts['ids'] = ids
              base_counts['count'] = count
            end

            times = []
            repetitions.times do
              times << Benchmark.ms { endpoint.things.page(1).reload }
            end

            count_times = []
            repetitions.times do
              count_times << Benchmark.ms { endpoint.things.count }
            end

            avg = times.sum / times.size
            count_avg = count_times.sum / count_times.size
            strategy_times[strategy] = [avg, count_avg]

            output_color = nil
            output_color_count = nil

            if strategy_times[base_strategy].present? && strategy_times[strategy].present? && base_strategy != strategy
              if ((strategy_times[base_strategy].first - strategy_times[strategy].first) / strategy_times.values.map(&:first).max) > 0.25
                output_color = :green
              elsif ((strategy_times[base_strategy].first - strategy_times[strategy].first) / strategy_times.values.map(&:first).max) < -0.25
                output_color = :red
              end

              if ((strategy_times[base_strategy].last - strategy_times[strategy].last) / strategy_times.values.map(&:last).max) > 0.25
                output_color_count = :green
              elsif ((strategy_times[base_strategy].last - strategy_times[strategy].last) / strategy_times.values.map(&:last).max) < -0.25
                output_color_count = :red
              end

              full_output_color = :red if ids != base_counts['ids'] || count != base_counts['count']
            end

            time_text = "#{avg.round}ms"
            time_text = AmazingPrint::Colors.send(output_color, time_text) unless output_color.nil?
            count_time_text = "count: #{count_avg.round}ms"
            count_time_text = AmazingPrint::Colors.send(output_color_count, count_time_text) unless output_color_count.nil?

            csv << [strategy, avg.round, count_avg.round]
            full_text = "#{strategy.to_s.rjust(20)}: #{time_text} (#{count_time_text})"
            full_text = AmazingPrint::Colors.send(full_output_color, full_text) unless full_output_color.nil?

            puts full_text
          end

          puts '----------------------'
        rescue StandardError => e
          csv << ['Error', endpoint.id, e.message]
          puts AmazingPrint::Colors.red "Error comparing filter strategies for endpoint #{endpoint.id}: #{e.message}"
        end
      end

      puts AmazingPrint::Colors.green('[✔] ... Finished comparing filter strategies')
    end
  end
end
