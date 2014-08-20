require 'thread'
require 'optparse'
#p4 dirs //fcc-data-source/*/*
def preload(dir, user, passwd, instance)
    # TODO
    # p4 login
    # check old process
    # write log to file
    # mail
    puts "variable: #{dir}, #{user}, #{passwd}, #{instance}"
end

def pfdir(path, user=options[:user], passwd=options[:passwd], instance=options[:instance])
    # TODO
end

options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: opt.rb -t 3 -d 2 -l log -r //fcc-data-source/ -i sha-acu-dlc:1888 -u test -p test [options]"

    opts.on('-t N', '--thread NUMBER', Integer, 'How many threads runing together(1-20)') do |value|
        options[:thread] = value
    end

    opts.on('-d N', '--depth NUMBER', Integer, 'How deep would the dir look for(1-2)') do |value|
        options[:depth] = value
    end

    opts.on('-l LOG', '--log LOG', 'Log file to save logs') do |value|
        options[:log] = value
    end

    opts.on('-r ROOTPATH', '--root ROOTPATH', 'What is the preload root path') do |value|
        options[:root] = value
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
end

begin
    opt_parser.parse!
    mandatory = [:thread, :root, :depth, :log, :instance, :user, :passwd]
    missing = mandatory.select{ |param| options[param].nil? }
    if not missing.empty?
        raise OptionParser::MissingArgument, "Missing options: #{missing.join(', ')}"
    end
    if not (1..20).include?(options[:thread])
        raise OptionParser::InvalidArgument, 'Thread number is out of scope(1-20)'
    end
    if not (1..2).include?(options[:depth])
        raise OptionParser::InvalidArgument, 'Depth number is out of scope(1-2)'
    end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument, OptionParser::InvalidArgument
    puts $!.to_s
    puts opt_parser
    exit
end

case options[:depth]
when 1
    dirs = %x{ ls -1d #{options[:root]}/*/ }.split
    #dirs = pfdir(path)
when 2
    dirs = %x{ ls -1d #{options[:root]}/*/*/ }.split
else
    puts "nothing"
end

if options[:thread] > dirs.count
    num_of_thread = dirs.count
else
    num_of_thread = options[:thread]
end

puts "num of thread is #{num_of_thread}"

mutex = Mutex.new
resource = ConditionVariable.new
count = 0
threads = []
dirs.each do |dir|
    threads << Thread.new {
        mutex.synchronize {
            while count > num_of_thread
                resource.wait(mutex)
            end
            count +=1
            print "first count: "
            puts count
        }
        preload(dir, user=options[:user], passwd=options[:passwd], instance=options[:instance])
        sleep rand(9)
        mutex.synchronize {
            count -=1
            print "second cont: "
            puts count
            resource.signal
        }
    }
end
threads.each do |td|
    td.join
end
