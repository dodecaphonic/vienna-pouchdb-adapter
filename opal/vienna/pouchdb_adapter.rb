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
          block.call(update_model(model, attributes)) if block
        end
      end.fail do |error|
        model.trigger :pouchdb_error, error.message
      end
    end

    def create_record(record, &block)
      data = prepare_data(record)
      promise = if record.id
                  database.put(data.merge(_id: record.id))
                else
                  database.post(data)
                end

      promise.then do |attributes|
        record.load(data.merge(id: attributes[:id], _vienna_pouchdb: {
                                 _id: attributes[:id],
                                 _rev: attributes[:rev],
                                 rbtype: record.class.to_s
                               }))

        record.did_update
        record.class.trigger :change, record.class.all

        block.call(record) if block
      end.fail do |error|
        record.trigger :pouchdb_error, error.message
      end
    end

    def update_record(record, &block)
      data = prepare_data(record)

      database.put(data).then do |updated|
        record.load(data.merge(_vienna_pouchdb: { _rev: updated[:rev] }))

        record.did_update
        record.class.trigger :change, record.class.all

        block.call(record) if block
      end.fail do |error|
        record.trigger :pouchdb_error, error.message
      end
    end

    private

    def prepare_data(record)
      data = record.as_json
             .merge(rbtype: record.class.to_s)
             .reject { |k, _| k == :id }

      if (pouch_data = record[:_vienna_pouchdb])
        data.merge(pouch_data)
      else
        data
      end
    end

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
