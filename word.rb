class Word
  attr_accessor :name, :definition, :kinds, :gender, :alternate_forms

  @definition = Hash.new
  @kinds = Hash.new
  @gender = Hash.new
  @alternate_forms = Hash.new

  def initialize name
    @name = name
  end
end
