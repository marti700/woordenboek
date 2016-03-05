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

  def crawl a_word
    #gets definitions for the given word

    #sets the value of the search form value property (which name is search)
    #to the word paset to the method
    @search.search = a_word
    #submit the form to get the new Page
    @page = @search.submit
    extract_definitions_from @page
  end

  def extract_definitions_from a_page
    #extracts definitions from the given Mechanize::Page object

    word = Hash.new
    definitions = Hash.new
    #examples = Hash.new
    definition_counter = 1
    #examples_counter = 1

    #the xpath query that is passed to the search method says the following:
    #get all the h3 with a span with a class named mw-headline as children
    #that has a span that do not contains the word References, Prononciation
    #and Etymologie.
    #
    #Les Prononciations, Etymologies et les References
    #sont pas besoin dans ce dictionnaire
    a_page.search("//h3/span[@class='mw-headline']/span[not(contains(.,'Références' )
                  or contains(.,'Prononciation') or contains(.,'Symbole')
                  or contains(.,'Étymologie') or contains(.,'Voir aussi')
                  or contains(.,'Anagrammes'))]
                  [not(preceding::h2/span[@id = '#{limit_id}'])]").each do |heading|

      #the argument of the .at method is an xpath that queries for an specific
      #definition li of an ol(all definitions all between <ol> tags) each
      #iteration the definition_counter variable increases by one and this
      #selects a different definition li from the <ol> tag as long as the .at
      #method do not return nil(which means there are no more definitions for
      #the current kind) the code inside the while loop will be executed
      while a_page.at("//ol/li[#{definition_counter}][preceding::span[@id='#{heading.attr('id')}']]") do
        currently_selected_item = a_page.at("//ol/li[#{definition_counter}][preceding::span[@id = '#{heading.attr('id')}']]")
        #The li tags from the above xpath query also get the text of the
        #examples of the the definitions. The definitions are separated from
        #the example by one or more new line characters, the /^(.*?)\n/ regex
        #takes the text that is before the first \n character.
        begin
          definitions[definition_counter] = /^(.*?)\n/.match(currently_selected_item.text)[0]
        rescue NoMethodError #there are no examples in for this specific definition, so the \n charecter magic is not needed
          definitions[definition_counter] = currently_selected_item.text
        end

        definition_counter += 1 #increase definition_counter to select the next definition <li>
      end
      definition_counter = 1 #resets definition_counter to select definitions for another kind
      word[heading.text.downcase.gsub(' ','_')] = {definitions: definitions}
      definitions = {} #clears the definitions hash to saves definitions for another kind
    end
    #A Hash containing the difinitions of a Word. This hash have the structure
    #{kind: definitions: 1: 'adsf', 2: 'adsfasf', 3: 'etc'}
    word
  end

  private
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
end


c = Crawler.new 'https://fr.wiktionary.org/wiki/Wiktionnaire:Page_d%E2%80%99accueil'
p c.crawl 'fasse'

