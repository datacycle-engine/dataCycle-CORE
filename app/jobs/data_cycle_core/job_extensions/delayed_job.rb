# frozen_string_literal: true

module DataCycleCore
  module JobExtensions
    module DelayedJob
      extend ActiveSupport::Concern

      module ClassMethods
        def queue_with_reference_id(ref_id = nil, &block)
          self.reference_id = block || ref_id
        end

        def queue_with_reference_type(ref_type = nil, &block)
          self.reference_type = block || ref_type
        end

        def find_by_identifiers(reference_id:, reference_type:, queue_name:)
          delayed_job = Delayed::Job.find_by(queue: queue_name, delayed_reference_id: reference_id, delayed_reference_type: reference_type)

          return if delayed_job.nil?

          job = deserialize(YAML.load(delayed_job.handler).job_data) # rubocop:disable Security/YAMLLoad
          job.provider_job_id = delayed_job.id
          job.send(:deserialize_arguments_if_needed)

          job
        end
      end

      included do
        class_attribute :reference_id, instance_accessor: false
        class_attribute :reference_type, instance_accessor: false
      end

      def initialize(*)
        super

        @reference_id = self.class.reference_id
        @reference_type = self.class.reference_type
      end

      def destroy
        Delayed::Job.find(provider_job_id).destroy
      end

      def reference_id
        @reference_id = instance_exec(&@reference_id) if @reference_id.is_a?(Proc)
        @reference_id
      end
      alias delayed_reference_id reference_id

      def reference_type
        @reference_type = instance_exec(&@reference_type) if @reference_type.is_a?(Proc)
        @reference_type
      end
      alias delayed_reference_type reference_type
    end
  end
end
