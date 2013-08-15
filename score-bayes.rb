#!/usr/bin/ruby
require 'yaml'

DEBUGGING = false
MAX_NUM_HAM = 500
MAX_NUM_SPAM = 500
mboxes = YAML::load(File.open('manifest.yml'))

$false_pos = 0;
$false_neg = 0;
$total = 0;

def score_message(message, verbose=false)
    score = nil
    command = './bayes-score.rb'
    command += ' -v' if verbose

    IO.popen(command,'r+') do |pipe|
        pipe.puts message
        pipe.close_write
        score = pipe.read.chomp
    end
    score
end

def check_score(score_fields)
    $total += 1
    if score_fields[1] #if it is spam
        if score_fields[0].to_f < 0.1
            $false_neg += 1
            puts "FALSE NEG: #{score_fields[0..3].join(",")}"
            puts score_fields[4]
            puts score_message(score_fields[4], true)
        end
    else
        if score_fields[0].to_f >= 0.1
            $false_pos += 1
            puts "FALSE POS: #{score_fields[0..3].join(",")}"
            puts score_fields[4]
            puts score_message(score_fields[4], true)
        end
    end
end

def score_mboxes(mboxes, is_spam, max_num)

    num_emails = 0
    words = Hash.new(0)
    mboxes.each do |mbox_file|
        break if num_emails > max_num
        #info "Parsing ham mbox file: #{mbox_file}"

        message = ''
        IO.foreach(mbox_file) do |line|
            line.force_encoding("ISO-8859-1").encode!('UTF-8', {:invalid => :replace, :undef=>:replace, :replace=>'|?|'})
            if line.match(/^From /)
                if message != ''
                    matches = message.match(/^Subject:(.*)$/)
                    score = score_message(message)
                    check_score([score, is_spam, mbox_file, matches[1].gsub(',',''), message])
                end
                num_emails += 1
                break if num_emails > max_num
                message = line
            else
                message += line
            end
        end
        if message != ''
            matches = message.match(/^Subject:(.*)$/)
            unless matches
                puts message
            end
            score = score_message(message)

            check_score([score, is_spam, mbox_file, matches[1].gsub(',',''), message])
        end
    end
end

score_mboxes(mboxes["ham"], false, MAX_NUM_HAM)
score_mboxes(mboxes["spam"], true, MAX_NUM_SPAM)

puts "#{$false_pos}/#{$total} false positive (#{$false_pos.to_f*100/$total} %)"
puts "#{$false_neg}/#{$total} false negative (#{$false_neg.to_f*100/$total} %)"
