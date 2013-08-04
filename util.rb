
def info(msg)
    puts "#{Time.now.strftime("%F %T")} [INFO]  #{msg}"
end

def error(msg)
    puts "#{Time.now.strftime("%F %T")} [ERROR]  #{msg}"
end

