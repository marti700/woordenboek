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
end

