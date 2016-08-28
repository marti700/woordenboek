require_relative 'crawler'
require_relative 'word'
require 'json'

class Woordenboek
  attr_accessor :crawler, :dic
  def initialize
    @crawler = Crawler.new 'https://fr.wiktionary.org/wiki/Wiktionnaire:Page_d%E2%80%99accueil'
    @dic = Hash.new
  end

  def define a_word, with_examples = false
    #gets the definition for a_word
    @crawler.search a_word #get the word definition page
    w = Word.new a_word
    w.kinds = @crawler.kinds
    w.definition = @crawler.extract_definitions_from_page with_examples
    w.gender = @crawler.get_word_gender
    w.alternate_forms = @crawler.extract_alternate_forms
    w
  end

  def define_from a_path, with_examples = false
    #creates a dictionary taking the words from a text file
    #if with_example is true each word in the text file will be defined with
    #examples

    File.open(a_path, "r") do |f|
      f.each_line do |line|
        @dic[line.chomp] = define(line.chomp, with_examples).to_h
      end
    end
    @dic
  end

  def save_as_json path = './'
    File.open("#{path}test.json", "w") do |f|
      f.write(@dic.to_json)
    end
  end
end

dic = Woordenboek.new
#p dic.define 'ce'

dic.define_from("./test.txt").each do |key,value|
  puts(key +"-----------> " + value.to_s)
  #puts key
end

dic.save_as_json
