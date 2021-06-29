require 'bundler/setup'
Bundler.setup

require 'combine_pdf'

Dir["#{File.dirname(File.expand_path(__FILE__))}/support/**/*.rb"].each do |f|
  require f
end

RSpec.configure do |config|
  config.include FilesHelper

end
