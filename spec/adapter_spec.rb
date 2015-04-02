require "spec_helper"

class Widget < Vienna::Model
  adapter Vienna::PouchDBAdapter

  attributes :name, :part_number
end

class Violet < Vienna::Model
  adapter Vienna::PouchDBAdapter

  attributes :owner
end

describe Vienna::PouchDBAdapter do
  before do
    Vienna::PouchDBAdapter.configure do |c|
      c.database_name = "test-database-#{rand(1337)}-#{rand(3771)}"
    end
  end

  after do
    ev =  Widget.instance_variable_get("@eventable")
    %i(refresh pouchdb_error :update).each do |e|
      ev[e] = []
    end

    db.destroy()
  end

  let(:db) { Vienna::PouchDBAdapter.database }
  let(:raw_doc) {
    { name: "Golden Cog", part_number: 1337 }
  }

  describe "#find" do
    it "has this test because it needs to exist for async to run don't know why"

    async "fills in a Model's data" do
      db.put(raw_doc.merge(rbtype: "Widget", _id: "widget-1")).then do
        Widget.find("widget-1") do |w|
          async do
            expect(w.name).to eq("Golden Cog")
            expect(w.id).to eq("widget-1")
            expect(w.part_number).to eq(1337)
          end
        end
      end
    end

    async "triggers error if stored type doesn't match the Model's" do
      db.put(raw_doc.merge(_id: "widget-1", rbtype: "OtherType")).then do
        Widget.on :pouchdb_error do |error|
          async do
            expect(error).to match(/wrong type/i)
          end
        end

        Widget.find("widget-1")
      end
    end
  end

  describe "creating Records" do
    async "generates an id if one is not provided" do
      w = Widget.new(name: "New Shiny", part_number: 3771)

      expect(w.new_record?).to be(true)

      w.save do |cw|
        async do
          expect(cw.id).not_to be_nil
          expect(cw).to be(w)
          expect(w.new_record?).to be(false)
        end
      end
    end

    async "saves correctly if an id is provided" do
      w = Widget.new(raw_doc.merge(id: "widget-1"))

      expect(w.new_record?).to be(true)

      w.save do
        async do
          expect(w.id).to eq("widget-1")
          expect(w.new_record?).to be(false)
        end
      end
    end

    async "triggers the 'update event' when created" do
      w = Widget.new(raw_doc)

      w.on :update do
        async do
          expect(true).to be(true)
        end
      end

      w.save
    end

    async "triggers 'pouchdb_error' if something goes wrong on the pouch size" do
      w0 = Widget.new(raw_doc.merge(id: "widget-1"))
      w1 = Widget.new(raw_doc.merge(id: "widget-1"))

      w1.on :pouchdb_error do |error|
        async do
          expect(error).to match(/conflict/)
        end
      end

      w0.save do
        w1.save
      end
    end
  end

  describe "updating records" do
    async "changes data and the internal rev" do
      w = Widget.new(raw_doc)

      w.save do
        w.name = "Magic Cog"
        rev0 = w[:_vienna_pouchdb][:_rev]

        w.save do |uw|
          async do
            rev1 = w[:_vienna_pouchdb][:_rev]
            expect(uw.name).to eq("Magic Cog")
            expect(uw).to be(w)
            expect(rev1).not_to eq(rev0)
          end
        end
      end
    end

    async "triggers the 'change' event" do
      async "changes data and the internal rev" do
        w = Widget.new(raw_doc)

        w.on :change do
          async do
            expect(true).to be(true)
          end
        end

        w.save do
          w.name = "Magic Cog"
          w.save
        end
      end
    end
  end

  describe "deleting records" do
    async "really removes them from the database" do
      w = Widget.new(raw_doc.merge(_id: "widget-1"))

      w.save do
        w.destroy do
          db.get("widget-1").fail do |e|
            async do
              expect(e.message).to match(/missing/)
            end
          end
        end
      end
    end
  end

  describe "fetching collections" do
    async "only includes documents of the Model's type" do
      Violet.new(owner: "Jessica").save do
        Widget.new(raw_doc).save do
          Widget.fetch do |ws|
            async do
              expect(ws.size).to eq(1)
              expect(ws.all? { |w| w.class == Widget }).to be(true)
            end
          end
        end
      end
    end

    async "triggers 'refresh' event" do
      Widget.new(raw_doc).save do
        Widget.on :refresh do |d|
          async do
            expect(true).to be(true)
          end
        end

        Widget.fetch
      end
    end
  end
end
