
def debug(msg)
    puts "#{Time.now.strftime("%F %T")} [DEBUG]  #{msg}"
end
def info(msg)
    puts "#{Time.now.strftime("%F %T")} [INFO]  #{msg}"
end
def warn(msg)
    puts "#{Time.now.strftime("%F %T")} [WARN]  #{msg}"
end
def error(msg)
    puts "#{Time.now.strftime("%F %T")} [ERROR]  #{msg}"
end

