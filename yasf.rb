#!/usr/bin/ruby

require 'yaml'
require 'mail'
require 'dnsruby'
require_relative 'mbox'
require_relative 'attribute_table'
require_relative 'util'

MAX_NUM_HAM = 500
MAX_NUM_SPAM = 250
mboxes = YAML::load(File.open('manifest.yml'))

table = AttributeTable.new('data/classification.txt')

ham = Corpus.new
num_ham = 0
mboxes["ham"].each do |mbox_file|
    break if num_ham > MAX_NUM_HAM
    info "Parsing ham mbox file: #{mbox_file}"

    mbox = Mbox.new(mbox_file, MAX_NUM_HAM-num_ham)
    table.read_mbox(mbox, 0)

    ham.mboxes << mbox

    num_ham += mbox.messages.size
end
info "Parsed #{num_ham} ham messages"
info "Computing Word Counts..."
ham.compute_word_counts
info "Identified #{ham.words.size} unique words"
#ham_words.sort{|a,b| b[1] <=> a[1]}.each do |word, count|
#    puts "#{word}:#{count}"
#end
#exit

spam = Corpus.new
num_spam = 0
mboxes["spam"].each do |mbox_file|
    break if num_spam > MAX_NUM_SPAM
    info "Parsing spam mbox file: #{mbox_file}"

    mbox = Mbox.new(mbox_file, MAX_NUM_SPAM-num_spam)
    table.read_mbox(mbox, 1)

    spam.mboxes << mbox
    num_spam += mbox.messages.size
end
info "Parsed #{num_spam} spam messages"
info "Computing Word Counts..."
spam.compute_word_counts
info "Identified #{spam.words.size} unique words"

info "Writing classification matrix to #{table.outfile}..."
table.write
info "Complete."



#mbox.messages.each_with_index do |message,i|
#    puts "\nMessage #{i}"
#    message.compute_spam_scores
#    puts message.envelope_from
#    puts message.from
#    puts "Domains Match?: #{message.spam[:env_message_domains_match]}"
#end


#res = Dnsruby::Resolver.new
#record = res.query("google.com", Dnsruby::Types.TXT)
#puts record
