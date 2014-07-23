require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake'
# require 'bundler/gem_tasks'

###########
# Jeweler #
###########
require 'jeweler'
require_relative 'lib/nsq'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "nsq"
  gem.version = Nsq::Version::STRING
  gem.homepage = "http://github.com/wistia/nsq-ruby"
  gem.license = "MIT"
  gem.summary = %Q{Ruby client library for NSQ}
  gem.description = %Q{}
  gem.email = "dev@wistia.com"
  gem.authors = ["Wistia"]
  gem.files = Dir.glob('lib/**/*.rb') + ['README.md']
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

#########
# Rspec #
#########
require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['spec'].execute
end
task :default => :spec

########
# RDoc #
########
require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ''

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "pipedream #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
