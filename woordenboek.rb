require 'crawler'
require 'word'

class Woordenboek
  attr_accessor :crawler
  def initialize
  end

  def define a_word
    #gets the definition for a_word
  end

  def define_with_examples a_word
    #gets the definition of a_word including examples
  end

  def define_from a_path with_examples = false
    #creates a dictionary taking the words from a text file
    #if with_example is true each word in the text file will be defined with
    #examples
  end


end
