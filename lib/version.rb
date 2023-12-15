module Nsq
  module Version
    STRING = File.read(File.expand_path('../../VERSION', __FILE__)).strip
  end
end
