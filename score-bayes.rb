#!/usr/bin/ruby

input = []

ARGF.each do |line|
    input << line
end
1.upto(100) do |i|
    bayes_cutoff = i.to_f * 0.01
    puts "Computing with bayes cutoff at #{bayes_cutoff}"
    missclass = 0
    total = 0
    input.each do |line|
        line.chomp!
        score, is_spam = line.split("\t")

        total += 1
        if is_spam.to_i == 1
            missclass += 1 if score.to_f < bayes_cutoff
        else
            missclass += 1 if score.to_f >= bayes_cutoff
        end

    end
    correct = ((total - missclass) * 100).to_f / total
    wrong = (missclass * 100).to_f / total
    puts "#{missclass} misclassified out of #{total}. #{correct}\% correct, #{wrong}\% incorrect."
end

