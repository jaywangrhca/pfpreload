require 'thread'
require 'fileutils'
require 'net/smtp'
require 'optparse'
def login_test(user, passwd, instance, client)
    %x(
    export P4USER=#{user}
    export P4PASSWD=#{passwd}
    export P4CLIENT=#{client}
    export P4PORT=#{instance}
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4
    p4 groups
    )
end

def preload(dir, user, passwd, instance, client)
    puts "preloading dir: #{dir}"
    log_file = "#{$log_dir}/this_time_synced#{dir.gsub('/','_')}"
    %x(
    export P4USER=#{user}
    export P4PASSWD=#{passwd}
    export P4CLIENT=#{client}
    export P4PORT=#{instance}
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4
    if ! /usr/bin/pgrep -f "Zproxyload sync #{dir}"; then
        /opt/perforce/bin/p4 -p #{instance} -Zproxyload sync #{dir}/... &>#{log_file}
    else
        touch "#{$log_dir}/last_time_still_running#{dir.gsub('/','_')}"
    fi
    )
end

def pfdir(root, depth, user, passwd, instance, client)
    case depth
    when 0
        dir = "#{root}/*"
    when 1
        dir = "#{root}/*/*"
    when 2
        dir = "#{root}/*/*/*)"
    end
    %x(
    export P4USER=#{user}
    export P4PASSWD=#{passwd}
    export P4CLIENT=#{client}
    export P4PORT=#{instance}
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4
    p4 dirs #{dir}
    )
end

options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: opt.rb -t 3 -d 2 -r //fcc-data-source/ -i sha-acu-dlc:1888 -u test -p test [options]"

    opts.on('-t N', '--thread NUMBER', Integer, 'How many threads runing together(1-20)') do |value|
        options[:thread] = value
    end

    opts.on('-d N', '--depth NUMBER', Integer, 'How deep would the dir look for(0-2)') do |value|
        options[:depth] = value
    end

    #opts.on('-l LOG', '--log LOG', 'Log file to save logs') do |value|
    #    options[:log] = value
    #end

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

    opts.on('-c CLIENT', '--client CLIENT', 'Client for this instance') do |value|
        options[:client] = value
    end
end

begin
    opt_parser.parse!
    mandatory = [:thread, :root, :depth, :instance, :user, :passwd, :client]
    missing = mandatory.select{ |param| options[param].nil? }
    if not missing.empty?
        raise OptionParser::MissingArgument, "Missing options: #{missing.join(', ')}"
    end
    if not (1..20).include?(options[:thread])
        raise OptionParser::InvalidArgument, 'Thread number is out of scope(1-20)'
    end
    if not (0..2).include?(options[:depth])
        raise OptionParser::InvalidArgument, 'Depth number is out of scope(1-2)'
    end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument, OptionParser::InvalidArgument
    puts $!.to_s
    puts opt_parser
    exit
end

connection = login_test(options[:user], options[:passwd], options[:instance], options[:client])
if   connection =~ /^$/
    raise "Connection test failed, please check instance, username, passwrod!"
end

start_time = Time.now

dirs = pfdir(options[:root], options[:depth], options[:user], options[:passwd], options[:instance], options[:client]).split

#print "dirs are: "
#p dirs

if options[:thread] > dirs.count
    num_of_thread = dirs.count
else
    num_of_thread = options[:thread]
end

puts "num of thread is #{num_of_thread}"

epoch = Time.now.to_i
$log_dir = "/tmp/#{epoch}/#{options[:instance]}"
if not File.directory?($log_dir)
    FileUtils.mkdir_p($log_dir)
end

puts "log dir: #{$log_dir}"

mutex = Mutex.new
resource = ConditionVariable.new
count = 0
threads = []
dirs.each do |dir|
    threads << Thread.new {
        mutex.synchronize {
            while count >= num_of_thread
                resource.wait(mutex)
            end
            count +=1
        }
        preload(dir, options[:user], options[:passwd], options[:instance], options[:client])
        #sleep rand(5)
        mutex.synchronize {
            count -=1
            resource.signal
        }
    }
end
threads.each do |td|
    td.join
end

end_time = Time.now
FileUtils.cd($log_dir)
this_time = Dir.glob('this_time*')
last_time = Dir.glob('last_time*')
puts this_time
puts last_time
message = <<MESSAGE_END
From: Private Person <zu-jie.wang@ubisoft.com>
To: A Test User <zu-jie.wang@ubisoft.com>
Subject: SMTP e-mail test
Start time is #{start_time}
End time is #{end_time}
log folder is #{$log_dir}
#{this_time} is done
#{last_time} is syncing
This is a test e-mail message.
MESSAGE_END

Net::SMTP.start('localhost') do |smtp|
    smtp.send_message message, 'zu-jie.wang@ubisoft.com', 'zu-jie.wang@ubisoft.com'
end
