require "vienna"
require "pouchdb"

module Vienna
  class PouchDBAdapter < Adapter
    SPECIAL_ATTRIBUTES = [:_id, :_rev, :rbtype]
    ERROR_MESSAGES     = {
      wrong_type: "Wrong type for %s: expected %s, received: %s"
    }

    class << self
      def configure
        @configuration = Configuration.new
        @database      = nil

        yield @configuration
      end

      attr_reader :configuration

      def database
        fail "configure Adapter before usage" if !configuration

        @database ||= PouchDB::Database.new(name: configuration.database_name)
      end
    end

    def find(model, id, &block)
      database.get(id).then do |attributes|
        expected_type = model.class.to_s
        model_type    = attributes[:rbtype]

        if model_type != expected_type
          error_message = format_error(:wrong_type, id, model_type, expected_type)
          model.class.trigger :pouchdb_error, error_message
        else
          block.call(update_model(model, attributes))
        end
      end.fail do |error|
        model.trigger :pouchdb_error, error.message
      end
    end

    private

    def database
      self.class.database
    end

    def update_model(model, attributes)
      actual_attrs  = attributes.reject { |k, _| SPECIAL_ATTRIBUTES.member?(k) }
      special_attrs = attributes.select { |k, _| SPECIAL_ATTRIBUTES.member?(k) }
      final_attrs   = actual_attrs.merge(_vienna_pouchdb: special_attrs,
                                         id: special_attrs[:_id])

      model.load(final_attrs)

      model
    end

    def format_error(error_type, *args)
      format(ERROR_MESSAGES[error_type], *args)
    end


    Configuration = Struct.new(:database_name)
  end
end
