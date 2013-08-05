#!/usr/bin/ruby
require 'set'

PROB_FILE = 'data/spam_probs.txt'
WORD_REGEX = Regexp.new(/\w{3,}/)
NUM_WORDS = 15


email_words = Set.new
ARGF.each do |line|
    line.encode!('UTF-8', 'UTF-8', :invalid => :replace)
    line.scan(WORD_REGEX).each do |word|
        email_words << word
    end
end

#get the first NUM_WORDS from the file that are in the email
interesting_words = Set.new
IO.foreach(PROB_FILE) do |line|
    word, prob = line.chomp.split("\t")
    if email_words.include? word
        interesting_words << [word,prob.to_f]
        break if interesting_words.size >= NUM_WORDS
    end
end

products = 1.0
sums = 1.0
interesting_words.each do |word|
    #puts word.inspect
    products *= word[1]
    sums *= (1.0-word[1])
end

puts (products / (products + sums)).round(4)
