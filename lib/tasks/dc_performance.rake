# frozen_string_literal: true

# Benchmark.ms was removed from ActiveSupport in Rails 8.1 and is only available from the
# benchmark gem, which no longer gets required through activesupport.
require 'benchmark'

namespace :dc do
  namespace :performance do
    # Times the fan-out phase by phase, in the order DataCycleCore::Export::RelatedWebhooks#call
    # runs them, so a slow run can be attributed: the walk that resolves the linking contents, the
    # candidate narrowing per receiver, paging through the result, and the delivery enqueued per
    # content. The last one is the only phase whose cost scales with the number of linking
    # contents, so it is sampled and projected rather than run for all of them.
    desc 'measure the phases of the DataCycleCore::RelatedWebhooksJob fan-out for one content'
    task :related_webhooks, [:id, :system_name, :sample_size] => :environment do |_task, args|
      content = DataCycleCore::Thing.find(args[:id])
      sample_size = (args[:sample_size].presence || 100).to_i
      system_name = args[:system_name].presence || Array.wrap(DataCycleCore.webhooks).first
      raise ArgumentError, 'no receiver: pass one as the second argument or set WEBHOOKS' if system_name.blank?

      external_system = DataCycleCore::ExternalSystem.find_by!(name: system_name)
      # #execute_webhooks resolves the receivers through DataCycleCore.webhooks, which is empty
      # wherever WEBHOOKS is unset - a host used for measuring, typically
      original_webhooks = DataCycleCore.webhooks
      DataCycleCore.webhooks = [system_name]

      measure = lambda do |&block|
        queries = 0
        result = nil
        ms = 0
        ActiveSupport::Notifications.subscribed(->(*) { queries += 1 }, 'sql.active_record') do
          ms = Benchmark.ms { result = block.call }
        end
        [result, ms, queries]
      end

      label = ->(text) { text.to_s.ljust(22) }
      note = ->(text, detail) { puts "#{label.call(text)} #{detail}" }
      report = lambda do |text, ms, queries, detail|
        puts "#{label.call(text)} #{"#{ms.round}ms".rjust(9)} #{"#{queries} queries".rjust(14)}  #{detail}"
      end

      DataCycleCore::Thing.count # open the connection outside the first measurement

      related = DataCycleCore::Content::RelatedWebhooks.linking_contents(DataCycleCore::Thing.where(id: content.id))
      fan_out = DataCycleCore::Export::RelatedWebhooks.new(related:, system_names: [system_name])
      candidates = fan_out.send(:candidates, external_system)

      puts "#{content.template_name} #{content.id} -> #{system_name}"
      puts '---'

      linking_count, walk_ms, walk_queries = measure.call { related.count }
      report.call('linking contents', walk_ms, walk_queries, "#{linking_count} contents")

      next note.call('candidates', 'no endpoint resolves, the fan-out sends nothing') if candidates.nil?

      # #candidates hands back the very relation it was given when no endpoint is configured
      narrowed = !candidates.equal?(related)
      _, exists_ms, exists_queries = measure.call { candidates.exists? }
      report.call('candidates exists?', exists_ms, exists_queries, narrowed ? 'narrowed to endpoints' : 'not narrowed, no endpoints configured')

      paged, paging_ms, paging_queries = measure.call do
        loaded = 0
        candidates.find_each(batch_size: 1000) { loaded += 1 }
        loaded
      end
      report.call('paging', paging_ms, paging_queries, "#{paged} contents loaded")

      # Enqueued for real and deleted again below: SolidQueue writes the row on commit, so a
      # rollback would measure a job the queue never got.
      last_job_id = SolidQueue::Job.maximum(:id)
      sample = candidates.limit(sample_size).to_a
      next note.call('enqueue', 'nothing to enqueue') if sample.empty?

      _, enqueue_ms, enqueue_queries = measure.call do
        sample.each { |linking_content| linking_content.execute_webhooks(DataCycleCore::Export::RelatedWebhooks::ACTION, external_system_id: external_system.id) }
      end
      # The semaphores go with the jobs: one left behind holds the key at zero, so the next run
      # would find every enqueue blocked and measure the queue instead of the fan-out
      measured_jobs = SolidQueue::Job.where(id: (last_job_id.to_i + 1)..)
      concurrency_keys = measured_jobs.distinct.pluck(:concurrency_key)
      enqueued = measured_jobs.delete_all
      SolidQueue::Semaphore.where(key: concurrency_keys).delete_all
      report.call('enqueue', enqueue_ms, enqueue_queries, "#{(enqueue_ms / sample.size).round(1)}ms per content, #{enqueued} deliveries enqueued and deleted again")

      puts '---'
      projected = exists_ms + paging_ms + ((enqueue_ms / sample.size) * linking_count)
      puts "projected run: #{(projected / 1000).round(1)}s for #{linking_count} deliveries"
    ensure
      DataCycleCore.webhooks = original_webhooks unless original_webhooks.nil?
    end

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

    # What DataCycleCore::Webhook::Base.execute pays per content before it enqueues, measured the
    # way an importer pays it: once per content it saves. The filter query is not new work -
    # DataCycleCore::WebhookJob#check_filter ran the same one in the worker - so what this reports is
    # the share of it that moved into the import's own wall clock, against the solid_queue_jobs row
    # and semaphore it no longer writes for a content the filter rejects.
    #
    # Embedded contents are left out of the sample: #filter_endpoints rejects them before it queries
    # anything, and DataCycleCore::Webhook::Base.execute_all never reaches them either. +endpoint_id+
    # overrides the configured endpoint in memory, for measuring on a host whose config points at a
    # stored filter it does not have.
    #
    # The update filter only. A delete is the one action DataCycleCore::Export::Generic::Filter.filter
    # answers through #exported?, off external_system_syncs rather than any configured filter, so it
    # costs something else entirely.
    desc 'measure the inline export update filter cost per content, as an importer pays it'
    task :webhook_filter, [:system_name, :sample_size, :template_name, :endpoint_id] => :environment do |_task, args|
      system_name = args[:system_name].presence || Array.wrap(DataCycleCore.webhooks).first
      raise ArgumentError, 'no receiver: pass one as the first argument or set WEBHOOKS' if system_name.blank?

      sample_size = (args[:sample_size].presence || 500).to_i
      external_system = DataCycleCore::ExternalSystem.find_by!(name: system_name)

      if args[:endpoint_id].present?
        override = { 'export_config' => { 'filter' => { 'endpoints' => [args[:endpoint_id]] } } }
        external_system.config = external_system.config.deep_merge(override)
      end

      method_name = external_system.export_filter_method_name('update')
      endpoint_ids = DataCycleCore::Export::Generic::Filter.endpoint_ids_for(external_system, method_name)
      endpoints = DataCycleCore::Export::Generic::Filter.endpoints_for(external_system, method_name)

      # A filter that resolves to nothing rejects every content without querying, so the numbers
      # below would report the short circuit rather than the filter.
      raise "#{endpoint_ids.size} endpoint(s) configured, none of which resolve here - pass an endpoint_id that exists" if endpoint_ids.present? && endpoints.blank?

      scope = DataCycleCore::Thing.where.not(content_type: 'embedded')
      scope = scope.where(template_name: args[:template_name]) if args[:template_name].present?
      contents = scope.limit(sample_size).to_a
      raise ArgumentError, 'no contents to measure' if contents.empty?

      samples = contents.map do |content|
        utility_object = DataCycleCore::Export::PushObject.new(external_system:, action: 'update')
        queries = 0
        allowed = nil
        ms = 0

        ActiveSupport::Notifications.subscribed(->(*) { queries += 1 }, 'sql.active_record') do
          ms = Benchmark.ms { allowed = utility_object.allowed?(content) }
        end

        { ms:, queries:, allowed: }
      end

      times = samples.pluck(:ms).sort
      mean = times.sum / times.size

      puts "#{system_name} <- #{contents.size} contents (#{args[:template_name].presence || 'any template'})"
      puts "endpoints              #{endpoints.to_a.size} of #{endpoint_ids.size} configured resolve"
      puts '---'
      puts "filter passed          #{samples.count { |s| s[:allowed] }} of #{samples.size}"
      puts "reached the query      #{samples.count { |s| s[:queries].positive? }} of #{samples.size}"
      puts "queries per content    #{samples.pluck(:queries).sum.fdiv(samples.size).round(1)}"
      puts "mean                   #{mean.round(2)}ms"
      puts "p90                    #{times[(times.size * 0.9).floor].round(2)}ms"
      puts "max                    #{times.last.round(2)}ms"
      puts '---'
      [1_000, 10_000, 100_000].each do |n|
        puts "#{n} contents".ljust(23) + "#{(mean * n / 1000).round(1)}s added to the import"
      end
    end
  end
end
