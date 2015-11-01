# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: nsq-ruby 1.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "nsq-ruby"
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Wistia"]
  s.date = "2015-11-01"
  s.description = ""
  s.email = "dev@wistia.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "README.md",
    "lib/nsq.rb",
    "lib/nsq/client_base.rb",
    "lib/nsq/connection.rb",
    "lib/nsq/consumer.rb",
    "lib/nsq/discovery.rb",
    "lib/nsq/exceptions.rb",
    "lib/nsq/frames/error.rb",
    "lib/nsq/frames/frame.rb",
    "lib/nsq/frames/message.rb",
    "lib/nsq/frames/response.rb",
    "lib/nsq/logger.rb",
    "lib/nsq/producer.rb",
    "lib/version.rb"
  ]
  s.homepage = "http://github.com/wistia/nsq-ruby"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "Ruby client library for NSQ"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 2.0"])
      s.add_development_dependency(%q<nsq-cluster>, ["~> 1.1"])
      s.add_development_dependency(%q<rspec>, ["~> 3.0"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.0"])
      s.add_dependency(%q<jeweler>, ["~> 2.0"])
      s.add_dependency(%q<nsq-cluster>, ["~> 1.1"])
      s.add_dependency(%q<rspec>, ["~> 3.0"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.0"])
    s.add_dependency(%q<jeweler>, ["~> 2.0"])
    s.add_dependency(%q<nsq-cluster>, ["~> 1.1"])
    s.add_dependency(%q<rspec>, ["~> 3.0"])
  end
end

