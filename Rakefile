require "bundler"
Bundler.require

require "bundler/gem_tasks"
require "opal/rspec/rake_task"

Opal::RSpec::RakeTask.new(:default) do |s|
  s.index_path = "spec/pouchdb/index.html.erb"
end
