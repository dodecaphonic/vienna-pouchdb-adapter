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
      action = if record.id
                 database.put(data.merge(_id: record.id))
               else
                 database.post(data)
               end

      strategy = ->(r, created) do
        r.load(data.merge(id: created[:id], _vienna_pouchdb: {
                            _id: created[:id],
                            _rev: created[:rev],
                            rbtype: record.class.to_s
                          }))
      end

      perform(action,
              record: record,
              trigger_event: :did_update,
              callback: block,
              update_strategy: strategy)
    end

    def update_record(record, &block)
      data     = prepare_data(record)
      strategy = ->(r, updated) do
        r.load(data.merge(_vienna_pouchdb: { _rev: updated[:rev] }))
      end

      perform(database.put(data),
              record: record,
              trigger_event: :did_update,
              callback: block,
              update_strategy: strategy)
    end

    def delete_record(record, &block)
      perform(database.remove(doc: record[:_vienna_pouchdb]),
              record: record,
              trigger_event: :did_destroy,
              callback: block)
    end

    def fetch(model, options = {}, &block)
      database.all_docs(include_docs: true).then do |docs|
        klass   = model.to_s
        records = docs
                  .select { |d| d.document[:rbtype] == klass }
                  .map { |d| model.load(adapt_attributes(d.document)) }

        model.trigger :refresh, model.all

        block.call(records) if block
      end.fail do |error|
        model.trigger :pouchdb_error, error.message
      end
    end

    private

    def perform(promise, trigger_event:, record:, callback: nil,
                update_strategy: nil)
      promise.then do |changed|
        update_strategy.call(record, changed) if update_strategy
        record.public_send(trigger_event)
        record.class.trigger :change, record.class.all
        callback.call(record) if callback
      end.fail do |error|
        record.trigger :pouchdb_error, error.message
      end
    end

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

    def adapt_attributes(attributes)
      actual_attrs  = attributes.reject { |k, _| SPECIAL_ATTRIBUTES.member?(k) }
      special_attrs = attributes.select { |k, _| SPECIAL_ATTRIBUTES.member?(k) }
      actual_attrs.merge(_vienna_pouchdb: special_attrs, id: special_attrs[:_id])
    end

    def update_model(model, attributes)
      model.load(adapt_attributes(attributes))

      model
    end

    def format_error(error_type, *args)
      format(ERROR_MESSAGES[error_type], *args)
    end

    Configuration = Struct.new(:database_name)
  end
end
