class Word
  attr_accessor :name, :definition, :kinds, :gender, :alternate_forms

  @definition = Hash.new
  @kinds = Array.new
  @gender = Hash.new
  @alternate_forms = Hash.new

  def initialize name
    @name = name
  end

  def to_h
    #returns a Hash representing this object
    {@name.to_sym => {kinds: @kinds, definition: @definition, gender: @gender, alternate_forms: @alternate_forms}}
  end
end

