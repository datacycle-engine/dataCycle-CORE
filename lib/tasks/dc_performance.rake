# frozen_string_literal: true

namespace :dc do
  namespace :performance do
    desc 'override some files in project from core templates'
    task compare_union_filter_strategies: :environment do
      strategies = ['in', 'exists']
      endpoints = DataCycleCore::StoredFilter.where('collections.parameters::text ILIKE ?', '%union_filter_ids%').named.order(name: :asc)

      puts "Comparing union filter strategies for #{endpoints.size} endpoints"
      puts '---'

      endpoints.each do |endpoint|
        puts "Endpoint: #{endpoint.name} (##{endpoint.id})"

        # warm up
        endpoint.things.page(1).load
        endpoint.things.count

        strategy_counts = {}
        strategies.each do |strategy|
          DataCycleCore.union_filter_strategy = strategy

          times = []
          5.times do
            times << Benchmark.ms { endpoint.things.page(1).reload }
          end

          count_times = []
          5.times do
            count_times << Benchmark.ms { endpoint.things.count }
          end

          avg = times.sum / times.size
          count_avg = count_times.sum / count_times.size
          strategy_counts[strategy] = [avg, count_avg]

          output_color = nil
          output_color_count = nil

          if strategy_counts['in'].present? && strategy_counts['exists'].present?
            if ((strategy_counts['in'].first - strategy_counts['exists'].first) / strategy_counts.values.map(&:first).max) > 0.25
              output_color = :green
            elsif ((strategy_counts['in'].first - strategy_counts['exists'].first) / strategy_counts.values.map(&:first).max) < -0.25
              output_color = :red
            end

            if ((strategy_counts['in'].last - strategy_counts['exists'].last) / strategy_counts.values.map(&:last).max) > 0.25
              output_color_count = :green
            elsif ((strategy_counts['in'].last - strategy_counts['exists'].last) / strategy_counts.values.map(&:last).max) < -0.25
              output_color_count = :red
            end
          end

          time_text = "#{avg.round}ms"
          time_text = time_text.send(output_color) unless output_color.nil?
          count_time_text = "count: #{count_avg.round}ms"
          count_time_text = count_time_text.send(output_color_count) unless output_color_count.nil?

          puts "#{strategy.rjust(8)}: #{time_text} (#{count_time_text})"
        end

        puts '----------------------'
      rescue StandardError => e
        puts "Error comparing union filter strategies for endpoint #{endpoint.id}: #{e.message}"
      end

      puts 'Finished comparing union filter strategies'
    end
  end
end
