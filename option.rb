require 'optparse'
options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: example.rb [options]"

    opts.on('-t N', '--thread number', Integer, 'How many threads runing together') do |value|
        options[:thread] = value
    end
end.parse!


p options
p ARGV
