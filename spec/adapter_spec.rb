require "spec_helper"

class Widget < Vienna::Model
  adapter Vienna::PouchDBAdapter

  attributes :name, :part_number
end

describe Vienna::PouchDBAdapter do
  before do
    Vienna::PouchDBAdapter.configure do |c|
      c.database_name = "test-database-#{rand(1337)}-#{rand(3771)}"
    end
  end

  after do
    db.destroy()
  end

  let(:db) { Vienna::PouchDBAdapter.database }

  describe "#find" do
    let(:raw_doc) {
      { _id: "widget-1", name: "Golden Cog", part_number: 1337, rbtype: "Widget" }
    }

    it "has this test because it needs to exist for async to run don't know why"

    async "fills in a Model's data" do
      db.put(raw_doc).then do
        Widget.find("widget-1") do |w|
          async do
            expect(w.name).to eq("Golden Cog")
            expect(w.id).to eq("widget-1")
            expect(w.part_number).to eq(1337)
          end
        end
      end
    end

    async "triggers errors if stored type doesn't match the Model's" do
      db.put(raw_doc.merge(rbtype: "OtherType")).then do
        Widget.on :pouchdb_error do |error|
          async do
            expect(error).to match(/wrong type/i)
          end
        end

        Widget.find("widget-1")
      end
    end
  end
end
