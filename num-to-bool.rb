#!/usr/bin/ruby

file = []
ARGF.each do |line|
    row = line.chomp.split(",")
    file << row
end

new_file = []
file.each do |row|
    new_row = []
    row.each_with_index do |field,i|
        if i != 2
            if field == '1'
                new_row << 'true'
            elsif field == '0'
                new_row << 'false'
            else
                new_row << field
            end
        else
            new_row << field
        end
    end
    new_file << new_row
end

new_file.each do |row|
    puts row.join(",")
end

