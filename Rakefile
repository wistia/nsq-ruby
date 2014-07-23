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

###########
# Jeweler #
###########
require 'jeweler'
require_relative 'lib/version'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "nsq-ruby-client"
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
