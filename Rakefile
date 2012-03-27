require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'jeweler'

Jeweler::Tasks.new do |gem|
  gem.name = "iron_worker_ng"
  gem.homepage = "https://github.com/iron-io/iron_worker_ruby_ng"
  gem.description = %Q{New generation ruby client for IronWorker}
  gem.summary = %Q{New generation ruby client for IronWorker}
  gem.email = "info@iron.io"
  gem.authors = ["Andrew Kirilenko", "Iron.io, Inc"]
  gem.files.exclude('.document', 'Gemfile', 'Gemfile.lock', 'Rakefile', 'iron_worker_ng.gemspec', 'sample/**')
end

Jeweler::RubygemsDotOrgTasks.new
