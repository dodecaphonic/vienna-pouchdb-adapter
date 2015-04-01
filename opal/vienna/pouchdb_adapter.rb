require "vienna"
require "pouchdb"

module Vienna
  class PouchDBAdapter < Adapter
    class << self
      def configure
        @configuration = Configuration.new
        @database      = nil

        yield @configuration
      end

      attr_reader :configuration

      def database
        fail "configure Adapter before usage" if !configuration

        @database ||= PouchDB::Database.new(configuration)
      end
    end

    def find(model, id, &block)
      puts "I'm here"
      database.get(id).then do |attributes|
        puts "I'm there"
        block.call(model.load(attributes))
      end
    end

    private

    def database
      self.class.database
    end

    Configuration = Struct.new(:database_name)
  end
end
