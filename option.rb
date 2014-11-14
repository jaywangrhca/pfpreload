#!/usr/bin/ruby
require 'thread'
require 'logger'
require 'fileutils'
require 'net/smtp'
require 'optparse'
def p4proxy_test(user, passwd, instance, client)
    system(
    "export P4USER=#{user};
    export P4PASSWD=#{passwd};
    export P4CLIENT=#{client};
    export P4PORT=#{instance};
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4;
    echo $P4PASSWD | p4 login && p4 clients | grep #{client}"
    )
end

def preload(dir, user, instance, client, force)
    puts "preloading dir: #{dir}"
    preload_log_file = "#{$log_dir}/this_time_synced#{dir.gsub(/\/| /,'_')}"
    if ! system("/usr/bin/pgrep -f '#{instance} -Zproxyload sync #{force} #{dir}'")
#puts "start syncing #{dir} !"
        $logger.info("Start to sync #{dir} !")
        %x(
    export P4USER=#{user}
    export P4CLIENT=#{client}
    export P4PORT=#{instance}
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4
    p4 -p #{instance} -Zproxyload sync #{force} #{dir}/... &>#{preload_log_file}
        )
        $logger.info("Sync #{dir} is done !")
#puts "end syncing #{dir} !"
    else
#puts "Old process is syncing #{dir} !"
        $logger.warn("
######
Old process is syncing #{dir} !
######")
    end
end

def pfdir(root, depth, user, instance, client)
    root = root.sub(/\/\.*$/,'')
    puts root
    case depth
    when 0
        dir = "#{root}/*"
    when 1
        dir = "#{root}/*/*"
    when 2
        dir = "#{root}/*/*/*"
    end

    %x(
    export P4USER=#{user}
    export P4CLIENT=#{client}
    export P4PORT=#{instance}
    export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4
    p4 dirs #{dir}
    )
end

def alert_mail(msg, recipient, instance)
    message = <<MESSAGE_END
From: #{$host_name } <root@example.com>
To: UPS <#{$email}>
Subject: #{$host_name} instance #{instance} preload
!!!!!!!!!!
#{msg}
!!!!!!!!!!
MESSAGE_END

    Net::SMTP.start('localhost') do |smtp|
        smtp.send_message message, 'root@example.com', recipient
    end
end

options = {}
opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: preload.rb -t 3 -d 1 -r //fcc-data-source -i sha-acu-dlc:1888 -u test -p test -c wks111 [options]"

    options[:force] = ''
    options[:thread] = 15
    options[:depth] = 0
    options[:mail] = 'UPS_APAC_Operations@example.com'

    opts.on('-t N', '--thread NUMBER', Integer, 'How many threads runing together(1-20), default is 15') do |value|
        options[:thread] = value
    end

    opts.on('-d N', '--depth NUMBER', Integer, 'How deep would the dir look for(0-2), default is 0') do |value|
        options[:depth] = value
    end

    opts.on('-l LOG', '--log LOG', 'Log file to save logs [Optional]') do |value|
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

    opts.on('-c CLIENT', '--client CLIENT', 'Client for this instance') do |value|
        options[:client] = value
    end

    opts.on('-f', '--force', 'Force sync [Optional]') do |value|
        options[:force] = '-f'
    end

    opts.on('-m Email', '--mail', 'Email address, format: a@a.com or "a@a.com b@b.com" [Optional]') do |value|
        options[:mail] = value
    end
end

begin
    raise "Error: No P4 binary!" if ! system("
export PATH=/opt/perforce/git-fusion/bin:/opt/perforce/git-fusion/libexec:/opt/perforce/usr/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/perforce/bin:/home/perforce/bin:/opt/perforce/bin/p4;  which p4 >/dev/null 2>&1")
rescue => error
    alert_mail(error, $email, options[:instance])
    raise
end


begin
    opt_parser.parse!
    mandatory = [:root, :instance, :user, :passwd, :client]
    missing = mandatory.select{ |param| options[param].nil? }
    if not missing.empty?
        raise OptionParser::MissingArgument, "Missing options: #{missing.join(', ')}"
    end
    if not (1..20).include?(options[:thread])
        raise OptionParser::InvalidArgument, 'Thread number is out of scope(1-20)'
    end
    if not (0..2).include?(options[:depth])
        raise OptionParser::InvalidArgument, 'Depth number is out of scope(0-2)'
    end
    $email = options[:mail].squeeze(' ').split(' ')
    $email.each do |email|
        raise OptionParser::InvalidArgument, 'Invalid Email address' if not email.match("^[a-zA-Z0-9_.-]+@[a-zA-Z0-9-]+.[a-zA-Z0-9.-]+$")
        end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument, OptionParser::InvalidArgument => error
    puts error
    puts opt_parser
    exit
end

epoch = Time.now.strftime("%Y%m%dT%H%M")

$host_name = `hostname -s`
log_name = options[:log] || "/tmp/p4p/#{epoch}_#{options[:instance]}.log"
puts "Log file is #{log_name}"
begin
    log_file = File.open(log_name, 'w')
rescue => error
    alert_mail("#{error}! Can't open to write log file: #{log_name} !" , $email, options[:instance])
    raise
end

$logger = Logger.new(log_file)
$logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime} #{severity}: #{msg}\n"
end
$logger.info("Program start:")
$logger.info("for instance: #{options[:instance]}, root path: #{options[:root]}, depth #{options[:depth]}, threads:  #{options[:thread]}")

if ! p4proxy_test(options[:user], options[:passwd], options[:instance], options[:client])
    $logger.error("Connection test failed! Check username, password and client!")
    begin
        raise "Connection test or p4 client test failed, please check instance, username, passwrod, client!"
    rescue => error
        alert_mail(error, $email, options[:instance])
        raise
    end
end

$logger.info("Script start!")
dirs = pfdir(options[:root], options[:depth], options[:user], options[:instance], options[:client]).split("\n")
dirs.reverse!

$logger.info("Preload for dirs: #{dirs}")

if options[:thread] > dirs.count
    num_of_thread = dirs.count
else
    num_of_thread = options[:thread]
end

puts "num of thread is #{num_of_thread}"

$logger.info("Real thread is #{num_of_thread} !")

$log_dir = "/tmp/p4p/#{options[:instance].split(':')[-1]}/#{epoch}"
$logger.info("Logs for preload are in #{$log_dir}")
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
        preload(dir, options[:user], options[:instance], options[:client], options[:force])
        mutex.synchronize {
            count -=1
            resource.signal
        }
    }
end
threads.each do |td|
    td.join
end

$logger.info("Preload is finished!")
$logger.close

log_contents = File.read(log_name)
message = <<MESSAGE_END
From: #{$host_name } <root@example.com>
To: UPS <#{$email}>
Subject: #{$host_name} instance #{options[:instance]} preload
#{log_contents}
MESSAGE_END

Net::SMTP.start('localhost') do |smtp|
    smtp.send_message message, 'root@example.com', $email
end
