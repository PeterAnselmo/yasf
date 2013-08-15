#!/usr/bin/ruby

require 'yaml'
require 'mail'
require 'dnsruby'
require_relative 'util'

DEBUGGING = false
MAX_NUM_HAM = 10000
MAX_NUM_SPAM = 10000
WORD_REGEX = Regexp.new(/[\w!]{3,}/)
mboxes = YAML::load(File.open('manifest.yml'))

def read_mboxes(mboxes, is_spam, max_num)

    num_emails = 0
    words = Hash.new(0)
    mboxes.each do |mbox_file|
        break if num_emails > max_num
        #info "Parsing ham mbox file: #{mbox_file}"

        IO.foreach(mbox_file) do |line|
            line.force_encoding("ISO-8859-1").encode!('UTF-8', {:invalid => :replace, :undef=>:replace, :replace=>'|?|'})
            line.scan(WORD_REGEX).each do |word|
                words[word] += 1
            end
            num_emails += 1 if line.match(/^From /)
            break if num_emails > max_num
        end
    end
    [words, num_emails]
    
    #info "Parsed #{num_ham} ham messages"
    #info "Identified #{ham_words.size} unique words"
    #i = 0
    #ham_words.sort{|a,b| b[1] <=> a[1]}.each do |word, count|
    #    puts "#{word}:#{count}"
    #    i += 1
    #    break if i > 50;
    #end
end

ham_words, num_ham = read_mboxes(mboxes["ham"], false, MAX_NUM_HAM)
spam_words, num_spam = read_mboxes(mboxes["spam"], false, MAX_NUM_SPAM)

spam_probs = Hash.new()

(ham_words.keys + spam_words.keys).each do |word|
    ham_count = ham_words[word] || 0
    spam_count = spam_words[word] || 0

    if ham_count + spam_count >= 5
        ham_freq = [ham_count.to_f/num_ham, 1.0].min
        spam_freq = [spam_count.to_f/num_spam, 1.0].min
        spam_prob = spam_freq / (ham_freq + spam_freq)
        spam_prob = [spam_prob,0.9999].min
        spam_prob = [spam_prob,0.0001].max
        spam_probs[word] = spam_prob
        if DEBUGGING
            puts "word: #{word}"
            puts "ham: #{ham_freq}"
            puts "spam: #{spam_freq}"
            puts "spam prob: #{spam_prob}"
        end
    end
end

spam_probs.sort{|a,b| (b[1]-0.5).abs <=> (a[1]-0.5).abs}.each do |word, count|
    puts "#{word}\t#{count}"
end

