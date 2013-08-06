
require_relative 'mbox.rb'
require_relative 'util.rb'

class AttributeTable
    attr_reader :table
    attr_accessor :outfile
    attr_accessor :delim

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
        :recip_message_domains_match,
        :spf_result,
        :has_dkim,
        :has_domain_key,
        :num_recipients,
        :env_reverse_lookup_match,
        :recip_reverse_lookup_match,
        :bad_encoding,
        :bayes_score
#        :all_reverse_lookups_match
    ]

    def initialize(new_outfile=nil)
        @table = Array.new
        @outfile = new_outfile if new_outfile
        @fh = File.open(@outfile, 'w')
        @delim = ","
        self
    end

    def write_header
        @fh.puts MBOX_COLUMNS.dup.push("is_spam").push("Filename").push("Subject").join(@delim)
    end

    def write_mbox(mbox, is_spam)
        mbox.messages.each do |message|

            s = message.spam
            row = Array.new
            MBOX_COLUMNS.each do |col|
                row << s[col]
            end
            row << is_spam
            row << mbox.filename
            row << "\"#{message.subject.to_s.gsub(/[,'"]/,' ')}\""

            @fh.puts row.join(@delim)
        end
        self
    end

    def close
        @fh.close unless @fh.nil?
    end

end
