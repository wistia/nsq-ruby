Gem::Specification.new do |s|
  s.name = "nsq-ruby".freeze
  s.version = File.read('VERSION')

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Wistia".freeze]
  s.date = "2018-04-13"
  s.description = "".freeze
  s.email = "dev@wistia.com".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir.glob('lib/**/*.rb') + ['README.md', 'VERSION']
  s.homepage = "http://github.com/wistia/nsq-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.8".freeze
  s.summary = "Ruby client library for NSQ".freeze

  s.add_development_dependency(%q<nsq-cluster>.freeze, ["~> 2.1"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
end
