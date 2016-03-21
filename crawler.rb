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

      #the argument of the .at method is an xpath that queries for an specific
      #definition li of an ol(all definitions all between <ol> tags) each
      #iteration the definition_counter variable increases by one and this
      #selects a different definition li from the <ol> tag as long as the .at
      #method do not return nil(which means there are no more definitions for
      #the current kind) the code inside the while loop will be executed
      while @page.at("//ol/li[#{definition_counter}][preceding::span[@id='#{heading.attr('id')}']]") do
        currently_selected_item = @page.at("//ol/li[#{definition_counter}][preceding::span[@id = '#{heading.attr('id')}']]")
        #The li tags from the above xpath query also get the text of the
        #examples of the the definitions. The definitions are separated from
        #the example by one or more new line characters, the /^(.*?)\n/ regex
        #takes the text that is before the first \n character.
        begin
          definitions[definition_counter] = /^(.*?)\n/.match(currently_selected_item.text)[0]
          examples[definition_counter] = extract_examples_from currently_selected_item if with_examples

        rescue NoMethodError #there are no examples in for this specific definition, so the \n charecter magic is not needed
          definitions[definition_counter] = currently_selected_item.text
          examples[definition_counter] = extract_examples_from currently_selected_item if with_examples
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

    @page.search("//h3/span[@class='mw-headline']/span[not(contains(.,'Références' )
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
end


c = Crawler.new 'https://fr.wiktionary.org/wiki/Wiktionnaire:Page_d%E2%80%99accueil'
p c.crawl 'journal'

