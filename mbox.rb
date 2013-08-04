require 'mail'
require 'resolv'
require_relative 'util'

DEBUGGING = false

module Mail
    class Message

        @@link_regex = Regexp.new(/https?:\/\/[\w\.]+/)
        @@html_link_regex = Regexp.new(/\<a.*href/)
        @@dkim_sig = Regexp.new(/^DKIM-Signature:/)
        @@dom_key_sig = Regexp.new(/^DomainKey-Signature:/)
        @@recipient_regex = Regexp.new(/from .*\(?EHLO ([^()]*)\)? \(.*?\[?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]?\)/)
        @@recipient_regex2 = Regexp.new(/from (.*) \(.*?\[?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]?.*?\)/)

        attr_accessor :spam

        def compute_spam_scores
            @spam = Hash.new

            @spam[:env_domain] = get_domain(envelope_from)
            @spam[:from_domain] = get_domain(from.last)

            @spam[:env_message_domains_match] = 0
            if @spam[:env_domain] && @spam[:from_domain] && (@spam[:env_domain] == @spam[:from_domain])
                @spam[:env_message_domains_match] = 1
            end

            @spam[:has_link] = (@@link_regex.match(self.body.to_s) != nil) ? 1 : 0
            @spam[:has_html_link] = (@@html_link_regex.match(body.to_s) != nil) ? 1 : 0
            @spam[:links] = body.to_s.scan(@@link_regex)
            @spam[:num_links] = @spam[:links].size

            @spam[:links_match_from] = 1
            @spam[:links].each do |link|
                if get_domain(link) != @spam[:from_domain]
                    @spam[:links_match_from] = 0
                    break
                end
            end

            #@spam[:recipients] = Array.new
            #(received.is_a?(Mail::Field)? [received] : received).each do |recipient|
            #    match = @@recipient_regex.match(recipient.to_s)
            #    if match && match.size == 3
            #        @spam[:recipients] << [match[1], match[2]]
            #    else
            #        match2 = @@recipient_regex2.match(recipient.to_s)
            #        if match2 && match2.size == 3
            #            @spam[:recipients] << [match2[1], match2[2]]
            #        else
            #            error "Unable to parse recipients string: #{recipient}"
            #        end
            #    end
            #end

            #@spam[:all_reverse_lookups_match] = 1
            #@spam[:recipients].each_with_index do |recip,i|
            #    begin
            #        reverse_domain = get_domain(Resolv.getname(recip[1]))
            #    rescue Resolv::ResolvError => e
            #        reverse_domain = nil
            #    end

            #    if DEBUGGING
            #        puts "Domain: #{recip[0]}"
            #        puts "IP: #{recip[1]}"
            #        puts "Reverse: #{reverse_domain}"
            #    end

            #    if i == 1
            #        @spam[:last_reverse_lookup_match] = (reverse_domain == get_domain(recip[0])) ? 1 : 0
            #    end
            #    @spam[:all_reverse_lookups_match] = 0 if reverse_domain != get_domain(recip[0])
            #end


            @spam[:has_dkim] = (@@dkim_sig.match(header.to_s)) ? 1 : 0
            @spam[:has_domain_key] = (@@dom_key_sig.match(header.to_s)) ? 1 : 0


            self
        end

        def get_domain(fqdn)
            return fqdn.split(/[@\.]/)[-2..-1]
        end
    end
end

class Mbox
    attr_reader :messages

    def initialize(path, max = nil)
        @messages = Array.new
        raw_message = ''
        num_read = 0
        IO.foreach(path) do |line|
            begin
                if line.match(/^From /)
                    if raw_message != ''

                        num_read += 1
                        message = Mail.new(raw_message)
                        info "#{num_read} read from this file"

                        begin
                            message.compute_spam_scores
                        rescue Mail::UnknownEncodingType => e
                            error e.message
                            next
                        end

                        @messages << message
                        return self if max && num_read > max
                    end
                    raw_message = line
                else
                    raw_message += line.sub(/^\>From/,'From')
                end
            rescue ArgumentError => e
                error "(In File: #{path}) #{e.message}"
            end
        end

        if raw_message != ''
            num_read += 1
            message = Mail.new(raw_message)
            info "#{num_read} read from this file"

            begin
                message.compute_spam_scores
            rescue Mail::UnknownEncodingType => e
                error e.message
            end

            @messages << message
        end
        self
    end
end

class Corpus

    @@word_regex = Regexp.new(/\w{3,}/)
    attr_reader :words
    attr_accessor :mboxes


    def initialize
        @words = Hash.new(0)
        @mboxes = Array.new
        self
    end

    def compute_word_counts
        @mboxes.each do |mbox|
            mbox.messages.each do |message|
                begin
                    message.to_s.scan(@@word_regex).each do |word|
                        @words[word] += 1;
                    end
                rescue NoMethodError => e
                    error e.message
                rescue ArgumentError => e
                    error e.message
                end
            end
        end
        self
    end

end