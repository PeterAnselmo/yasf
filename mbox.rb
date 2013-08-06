require 'mail'
require 'resolv'
require_relative 'util'

DEBUGGING = true

module Mail
    class Message

        @@link_regex = Regexp.new(/https?:\/\/[\w\.]+/)
        @@html_link_regex = Regexp.new(/\<a.*href/)
        @@dkim_sig = Regexp.new(/^DKIM-Signature:/)
        @@dom_key_sig = Regexp.new(/^DomainKey-Signature:/)
        @@recipient_regex = Regexp.new(/from .*\(?[HEL|ELH]O ([^()]*)\)? \(.*?\[?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]?\)/)
        @@recipient_regex2 = Regexp.new(/from (.*) \(.*?\[?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]?.*?\)/)
        @@py_spf = "pyspf-2.0.8/spf.py"
        @@spf_regex = Regexp.new(/^\('(.*?)',.*\)/)

        attr_accessor :spam

        def compute_spam_scores
            if DEBUGGING
                debug "Parsing message: '#{subject}'"
            end
                
            @spam = Hash.new

            begin
                @spam[:bad_encoding] = false

                @spam[:env_domain] = get_domain(return_path)
                @spam[:from_domain] = get_domain(from.last)

                @spam[:env_message_domains_match] = false
                if @spam[:env_domain] && @spam[:from_domain] && (@spam[:env_domain] == @spam[:from_domain])
                    @spam[:env_message_domains_match] = true
                end

                @spam[:has_link] = (@@link_regex.match(self.body.to_s) != nil)
                @spam[:has_html_link] = (@@html_link_regex.match(body.to_s) != nil)
                @spam[:links] = body.to_s.scan(@@link_regex)
                @spam[:num_links] = @spam[:links].size

                @spam[:links_match_from] = true
                @spam[:links].each do |link|
                    if get_domain(link) != @spam[:from_domain]
                        @spam[:links_match_from] = false
                        break
                    end
                end

                @spam[:recipients] = Array.new
                recipients_array = (received.is_a?(Mail::Field)? [received] : received)
                @spam[:num_recipients] = recipients_array.size
                recipients_array.each do |recipient|
                    match = @@recipient_regex.match(recipient.to_s)
                    if match && match.size == 3
                        @spam[:recipients] << [match[1], match[2]]
                    else
                        match2 = @@recipient_regex2.match(recipient.to_s)
                        if match2 && match2.size == 3
                            @spam[:recipients] << [match2[1], match2[2]]
                        else
                            warn "Unable to parse recipients string: #{recipient}"
                        end
                    end
                    break #just take the first recipient
                end

                recip = @spam[:recipients].first #reverse cron, first is last
                recip_domain = get_domain(recip[0])
                begin
                    reverse_domain = get_domain(Resolv.getname(recip[1]))
                rescue Resolv::ResolvError => e
                    reverse_domain = nil
                end
                @spam[:env_reverse_lookup_match] = (reverse_domain == @spam[:env_domain])
                @spam[:recip_reverse_lookup_match] = (reverse_domain == recip_domain)

                if DEBUGGING
                    debug "Domain: #{recip_domain} | IP: #{recip[1]} | Reverse: #{reverse_domain} | Match? #{@spam[:recip_reverse_lookup_match]}"
                end

                @spam[:recip_message_domains_match] = false
                if recip_domain && @spam[:from_domain] && (recip_domain == @spam[:from_domain])
                    @spam[:recip_message_domains_match] = true
                end

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


                @spam[:has_dkim] = (@@dkim_sig.match(header.to_s) != nil)
                @spam[:has_domain_key] = (@@dom_key_sig.match(header.to_s) != nil)

                spf_command = "#{@@py_spf} #{recip[1]} #{return_path} #{recip[0]}"
                debug "SPF COMMAND: #{spf_command}"
                raw_spf_result = `#{spf_command}`
                
                if spf_match = @@spf_regex.match(raw_spf_result)
                    @spam[:spf_result] = spf_match[1]
                else
                    @spam[:spf_result] = nil
                end

            rescue Mail::UnknownEncodingType => e
                warn e.message
                @spam[:bad_encoding] = true
            end

            IO.popen('./bayes-score.rb','r+') do |pipe|
                pipe.puts raw_source
                pipe.close_write
                @spam[:bayes_score] = pipe.read.chomp
            end

            self
        end

        def get_domain(fqdn)
            return fqdn.split(/[@\.]/)[-2..-1]
        end
    end
end

class Mbox
    attr_reader :messages
    attr_reader :filename

    def initialize(path, max = nil, compute_spam = true)
        @messages = Array.new
        @filename = path
        raw_message = ''
        num_read = 0
        IO.foreach(path) do |line|
            line.encode!('UTF-8', 'UTF-8', :invalid => :replace)
            begin
                if line.match(/^From /)
                    if raw_message != ''
                        message = Mail.new(raw_message)

                        unless message.subject && message.subject.include?('FOLDER INTERNAL DATA')
                            num_read += 1
                            info "#{num_read} read from this file"

                            message.compute_spam_scores if compute_spam

                            @messages << message
                            return self if max && num_read > max
                        end
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
            message = Mail.new(raw_message)
            unless message.subject && message.subject.include?('FOLDER INTERNAL DATA')
                num_read += 1
                info "#{num_read} read from this file"

                message.compute_spam_scores if compute_spam

                @messages << message
            end
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
