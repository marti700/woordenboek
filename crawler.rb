require 'mechanize'

class Crawler
  attr_reader :mech_agent, :page
  attr_accessor :search
  def initialize an_wiktionary_url
    #instantiate a mechanize object
    @mech_agent = Mechanize.new
    #get the page from the link passed to the object,
    #this preresents the current page in which the user is in
    @page = @mech_agent.get an_wiktionary_url
    #in wiktionary the first form is the one where you search for words
    @search = @page.forms.first
  end

  def crawl a_word, with_examples = false
    #gets definitions for the given word
    #The with_examples argument especifies if examples from the
    #@page should be extracted too.

    #sets the value of the search form value property (which name is search)
    #to the word paset to the method
    @search.search = a_word
    #submit the form to get the new Page
    @page = @search.submit
    extract_definitions_from_page with_examples
    #get_word_gender
    #extract_alternate_forms
  end

  private
  def extract_definitions_from_page with_examples = false
    #Extracts definitions from the @page variable
    #The with_examples argument especifies if examples from
    #@page should be extracted too.

    word = Hash.new
    definitions = Hash.new
    examples = Hash.new
    definition_counter = 1

    valid_kind_headers.each do |heading|
      #selects the ol that defines the word for the provided kind header
      current_ol = @page.at("//ol[preceding::span[@id='#{heading.attr('id')}']]")

      current_ol.children.each do |child|
        #skip children that just have "\n" as text
        next if child.text == "\n"
        begin
          definitions[definition_counter] = /^(.*?)\n/.match(child.text)[0]
          examples[definition_counter] = extract_examples_from child if with_examples

        rescue NoMethodError #there are no examples in for this specific definition, so the \n charecter magic is not needed
          definitions[definition_counter] = child.text
          examples[definition_counter] = extract_examples_from child if with_examples
        end

        definition_counter += 1 #increase definition_counter to select the next definition <li>
      end
      definition_counter = 1 #resets definition_counter to select definitions for another kind
      word[heading.text.downcase.gsub(' ','_')] = {definitions: definitions, examples: examples}
      definitions = {} #clears the definitions hash to saves definitions for another kind
      examples = {} #clears the examples hash to saves examples for another definition
    end
    #A Hash containing the difinitions of a Word. This hash have the structure
    #{:kind => :definitions => {1=> 'adsf', 2=> 'adsfasf', 3=> 'etc', :examples => 1=> list of examples}}
    #:examples will be an empty hash in case with_examples is set to false
    word
  end

  def limit_id
    #All french wiktionary pages have one or more <h2> tag with an span inside
    #the text of this span defines the context in which the word takes meaning
    #I just interested in the french context, so the ancient french and other
    #context will be ignored by this script.
    #
    #The job of this method is to get the id of the <h2> tag the comes after the
    #<h2> that hold the 'Français' text. Just the headings for the kinds (verbs, adjetif, etc)
    #that are above this point will be selected(not by this method this just returns the id of
    #the limit of the search).

    #get the id of the first span child of a <h2> tag that comes after a span
    #with an id of 'Fran.C3.A7ais' and is a child of a <h2> tag inside this <h2>
    #tag can be found the text 'Français'

    xpath_query = "//h2/span[preceding::h2/span[@id = 'Fran.C3.A7ais']]"
    selected_element = @page.at(xpath_query)

    if selected_element #if selected_element is not nil
      selected_element.attr('id')
    else
      "no match"
    end
  end

  def valid_kind_headers
    #returns an array of the valid kind headers
    #
    #the xpath query that is passed to the search method says the following:
    #get all the h3 with a span with a class named mw-headline as children
    #that has a span that do not contains the word References, Prononciation
    #and Etymologie.
    #
    #Les Prononciations, Etymologies et les References
    #sont pas besoin dans ce dictionnaire

    @page.search("//h3/span[@class='mw-headline'][not(contains(.,'Références' )
                  or contains(.,'Prononciation') or contains(.,'Symbole')
                  or contains(.,'Étymologie') or contains(.,'Voir aussi')
                  or contains(.,'Anagrammes'))]
                  [not(preceding::h2/span[@id = '#{limit_id}'])]")
  end

  def extract_examples_from current_li_element
    #Extracs definition from a provided Nokogiri::XML::Element which is a <li>
    #and return an Array of all the examples that are within the provided
    #li element
    #
    #Is wise to remember that all definitions are in <ol> tags and that all
    #examples are in <ul> tags as children of the <li> tags from the <ol> tags
    example_number = 1
    examples = Array.new

    #If there examples in current_li_element (in case the name is not descriptive
    #enough current_li_element is a Nokogiri::XML::Element that represents a <li> tag)
    #the while loop will execute and extract all examples.
    while current_li_element.at("ul/li[#{example_number}]") do
      current_example = current_li_element.at("ul/li[#{example_number}]")
      examples.push current_example.text
      example_number += 1
    end
    examples
  end

  def get_word_gender
    #returns a hash with the kind of the word as key and the word gender as value
    #e.x. => {"adjectif_démonstratif"=>"Masculin", "pronom_démonstratif"=>"invariable", "nom_commun"=>"féminin"}
    #
    #Genres are usually in a <p> tag placed right after the kind(Nom, adjectif, etc)
    #of the word, genders can be also found inside a table with class a named
    #'flextable-fr-mfsp' but not all the words fits this description il y a
    #words that just have the table autres just have the <p> tag and peut être
    #il y a mots qui n'a pas la table ou le <p> tag.
    #
    #Alors, this method gets the gender by first looking for the <p> tag if not
    #<p> tag containing one of the genders text('féminin', 'masculin') then this
    #method will look for genre in the table.

    gender_kind = Hash.new
    valid_kind_headers.each do |heading|
      #Getting the text of the <p> tag
      p_text = @page.at("//p[preceding::h3/span[contains(.,'nom') or contains(.,'adjectif')
                        or contains(.,'Nom') or contains(.,'Adjectif')]
                        and preceding::span[@id='#{heading.attr('id')}']]")
      gender = /(masculin|féminin)/.match(p_text)
      p gender
      if !p_text.nil? && !gender.nil?
        gender_kind[heading.text.downcase.gsub(' ', '_')] = gender[0]
        next #no need to search the table if the gender was taken from the <p> tag
      end

      #Getting the gender from the table
      row = 1
      #while the element exists
      while !@page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}]").nil? do
        #see if the word we want to know the gender of match one of the strings in the table
        if !/\b#{@page.at('//h1').text}\b/.match(@page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}][preceding::span[@id='fr-adj-d.C3.A9m']]")).nil?
          #returns the gender of the word which is in a <th> tag
          gender = @page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}]/th
                            [preceding::span[@id = '#{heading.attr('id')}']]")
          gender_kind[heading.text.downcase.gsub(' ', '_')] = gender.nil? ? "invariable" : gender.text
        end
        row += 1
      end
    end
    gender_kind
  end

  def extract_alternate_forms
    #There are words that are written diferent depending on it's gender or number
    #this method returns a hash which contains an alternate form as key and the way it is written
    #as value.
    #
    #This alternate forms are always in a table that with a class named 'flextable flextable-fr-mfsp'
    #for the noms the key will mostly be the plural with the way in which the plural is written for
    #the current word. For the adjetifs the mostratives and the other words in wich the writing changes
    #depending of the gender the keys of the hash will be 'masculin_singulier', 'femenin_singulier',
    #'Masculin_pluriel', femenin_pluriel, etc, the gender always after the number. if a key is not in the hash
    #nil will be returned and this means that the word has not such denomination E.x if the masculin_pluriel
    #of 'maison' is requested nil will be returned because maison is always femenin and does not vary with the gender
    #the correct will be to request the pluriel which in this case will be one of keys of the hash the other one will
    #be singulier which will have the value 'maison'.
    #

    row = 2
    column = 1
    alternate_forms = Hash.new
    #this will loops works like traversing a matrix the program will enter the loops if the
    #xpath query passed to the #at method is not nil
    while !@page.at("//table[@class='flextable flextable-fr-mfsp']/tr[1]/th[#{column}]").nil? do
      while !@page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}]").nil? do

        #takes the gender from the table
        key1 = @page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}]/th")
        #takes the number from the table
        key2 = @page.at("//table[@class='flextable flextable-fr-mfsp']/tr[1]/th[#{column}]")
        #build the key if key1 is nil means that the gender is not present in the table
        #in that case just the number will serve as key but if key1 is not null both the gender
        #and the number will be used to build the ke
        #and the number will be used to build the key.
        key = key1.nil? ? key2.text : key1.text+'_'+key2.text

        #gets the element that contains the value of the alternate form of this word
        value_element = @page.at("//table[@class='flextable flextable-fr-mfsp']/tr[#{row}]/td[#{column}]")
        #there are noms that has a aditional row without columns
        #this code below takes care of those exceptions
        break if value_element.nil?
        #usually the alternate forms in the table has the pronunciation in the follwing pattern
        #the value we are interested in a '\n' charactar and the pronunciation
        #(actually it is more complex than that but that is the relevant stuff)
        #so the regexp below takes the value we are interested in it says take all until the
        #first '\n' value and ingnore the rest
        value = /^(.*?)\n/.match value_element.text
        if alternate_forms.has_key? key
          row += 1
          next
        else
          alternate_forms[key] = value.nil? ? value_element.text : value[1]
        end
      row += 1
      end
      column += 1
      row = 2
    end
    alternate_forms
  end
end


c = Crawler.new 'https://fr.wiktionary.org/wiki/Wiktionnaire:Page_d%E2%80%99accueil'
p c.crawl 'ce'
