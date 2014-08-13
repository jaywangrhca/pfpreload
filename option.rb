require 'optparse'
options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: opt.rb -t 3 -d 3 -i sha-acu-dlc:1888 -u test -p test [options]"

    opts.on('-t N', '--thread NUMBER', Integer, 'How many threads runing together(1-20)') do |value|
        #TODO: if condition for value in 1-20
            options[:thread] = value
            #raise 'Thread number out of scope(1-20)'
    end

    opts.on('-d N', '--depth NUMBER', Integer, 'How deep would the dir look for(1-3)') do |value|
        options[:depth] = value
    end

    opts.on('-i INSTANCE', '--instance INSTANCE', 'Instance information') do |value|
        options[:instance] = value
    end

    opts.on('-u USER', '--user USER', 'User name for this instance') do |value|
        options[:user] = value
    end

    opts.on('-p PASSWORD', '--password PASSWORD', 'Password for this User') do |value|
        options[:passwd] = value
    end
end.parse!


p options
p ARGV
ROOT_DIR = './root'
dirs = []
case options[:depth]
when 1
    dirs = %x{ ls -1d #{ROOT_DIR}/*/ }.split
    #dirs = p4 dir
when 2
    dirs = %x{ ls -1d #{ROOT_DIR}/*/*/ }.split
when 3
    dirs = %x{ ls -1d #{ROOT_DIR}/*/*/*/ }.split
else
    puts "nothing"
end

p dirs
#TODO: thread limitation test
