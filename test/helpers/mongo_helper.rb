# frozen_string_literal: true

module DataCycleCore
  module MongoHelper
    def self.drop_mongo_db(external_source_name)
      external_source = DataCycleCore::ExternalSystem.find_by(name: external_source_name)
      external_source ||= DataCycleCore::ExternalSystem.find_by(identifier: external_source_name)
      id = external_source.id
      mongo_database = "#{Generic::Collection.database_name}_#{id}"
      Mongoid.override_database(mongo_database)
      Mongoid.clients[id] = {
        'database' => mongo_database,
        'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
        'options' => nil
      }
      Mongoid.client(id).database.drop
      Mongoid.override_database(nil)
    end
  end
end
