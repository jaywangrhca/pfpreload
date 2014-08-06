require 'thread'
require 'optparse'
mutex = Mutex.new
resource = ConditionVariable.new
count = 0
1.upto(10) do |id|
    id = Thread.new {
        mutex.synchronize {
            while count > 1
                resource.wait(mutex)
            end
        }
        count +=1
        puts "I'm in thread #{id}"
        sleep rand(9)
        count -=1
    }
    id.join
end
sleep while true
