require 'thread'
require 'optparse'
mutex = Mutex.new
resource = ConditionVariable.new
count = 0
threads = []
1.upto(10) do |id|
    id = Thread.new {
        mutex.synchronize {
            while count > 3
                resource.wait(mutex)
            end
            count +=1
            print "first count: "
            puts count
        }
        puts "I'm in thread #{id}"
        sleep rand(9)
        mutex.synchronize {
            count -=1
            print "second cont: "
            puts count
            resource.signal
        }
    }
    threads << id
end
threads.each do |td|
    # TODO
    td.join
end
