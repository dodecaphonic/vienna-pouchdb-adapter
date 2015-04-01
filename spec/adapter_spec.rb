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
    async "updates a model" do
      db.put(_id: "widget-1", name: "Golden Cog", part_number: 1337)
    end
  end
end
