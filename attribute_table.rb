
require_relative 'mbox.rb'
require_relative 'util.rb'

class AttributeTable
    attr_reader :table
    attr_accessor :outfile

    #this will be a 2d array, our classificaton matrix
    @table

    #path to write matrix to
    @outfile

    MBOX_COLUMNS = [
        :has_link,
        :has_html_link,
        :num_links,
        :links_match_from,
        :env_message_domains_match,
        :has_dkim,
        :has_domain_key,
#        :last_reverse_lookup_match,
#        :all_reverse_lookups_match
    ]

    def initialize(new_outfile=nil)
        @table = Array.new
        @outfile = new_outfile if new_outfile
        self
    end

    def read_mbox(mbox, is_spam)
        mbox.messages.each do |message|

            s = message.spam
            row = Array.new
            MBOX_COLUMNS.each do |col|
                row << s[col]
            end
            row << is_spam
            @table << row
        end
        self
    end


    def write(delim = "\t", header = true)
        File.open(@outfile, 'w') do |file|
            if header
                file.puts MBOX_COLUMNS.push("is_spam").join(delim)
            end
            @table.each do |row|
                file.puts row.join(delim)
            end
        end
    end

end
