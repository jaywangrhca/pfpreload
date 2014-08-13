require 'thread'
require 'optparse'
options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: opt.rb -t 3 -d 3 -i sha-acu-dlc:1888 -u test -p test [options]"

    opts.on('-t N', '--thread NUMBER', Integer, 'How many threads runing together(1-20)') do |value|
        if (1..20).include?(value)
            options[:thread] = value
        else
            raise 'Thread number is out of scope(1-20)'
        end
    end

    opts.on('-d N', '--depth NUMBER', Integer, 'How deep would the dir look for(1-3)') do |value|
        if (1..3).include?(value)
            options[:depth] = value
        else
            raise 'Depth is out of scope(1-3)'
        end
    end

    opts.on('-i INSTANCE', '--instance INSTANCE', 'Instance information') do |value|
        #TODO:
        # option requirment
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

ROOT_DIR = './root'
dirs = []
case options[:depth]
when 1
    dirs = %x{ ls -1d #{ROOT_DIR}/*/ }.split
    #dirs = pfdir(path)
when 2
    dirs = %x{ ls -1d #{ROOT_DIR}/*/*/ }.split
when 3
    dirs = %x{ ls -1d #{ROOT_DIR}/*/*/*/ }.split
else
    puts "nothing"
end

if options[:thread] > dirs.count
    num_of_thread = dirs.count
else
    num_of_thread = options[:thread]
end

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
        preload(dir)
        mutex.synchronize {
            count -=1
            print "second cont: "
            puts count
            resource.signal
        }
    }
end
threads.each do |td|
    # TODO
    td.join
end
def preload(dir, user=options[:user], passwd=options[:passwd], instance=options[:instance])
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
