module Ingreedy
  class RootParser < Parslet::Parser
    rule(:range) do
      amount_parser.as(:amount) >>
        whitespace.maybe >>
        str("-") >>
        whitespace.maybe >>
        amount_parser.as(:amount_end)
    end

    rule(:amount) do
      amount_parser.as(:amount)
    end

    rule(:whitespace) do
      match("\s")
    end

    rule(:container_amount) do
      amount_parser
    end

    rule(:unit) do
      if unit_matches.any?
        unit_matches.map { |u| str(u) }.inject(:|)
      else
        str("")
      end
    end

    rule(:container_unit) do
      unit
    end

    rule(:unit_and_preposition) do
      unit.as(:unit) >> (preposition_or_whitespace | any.absent?)
    end

    rule(:preposition_or_whitespace) do
      if prepositions.empty?
        whitespace
      else
        preposition | whitespace
      end
    end

    rule(:preposition) do
      whitespace >>
        prepositions.map { |con| str(con) }.inject(:|) >>
        whitespace
    end

    rule(:amount_unit_separator) do
      whitespace | str("-")
    end

    rule(:container_size) do
      # e.g. (12 ounce) or 12 ounce
      str("(").maybe >>
        container_amount.as(:container_amount) >>
        amount_unit_separator.maybe >>
        container_unit.as(:container_unit) >>
        str(")").maybe >> preposition_or_whitespace
    end

    rule(:amount_and_unit) do
      (range | amount) >>
        whitespace.maybe >>
        unit_and_preposition.maybe >>
        container_size.maybe
    end

    rule(:quantity) do
      amount_and_unit | unit_and_preposition
    end

    rule(:standard_format) do
      # e.g. 1/2 (12 oz) can black beans
      quantity >> any.repeat.as(:ingredient)
    end

    rule(:reverse_format) do
      # e.g. flour 200g
      ((whitespace >> quantity).absent? >> any).repeat.as(:ingredient) >>
        whitespace >>
        quantity
    end

    rule(:ingredient_addition) do
      standard_format | reverse_format
    end

    root :ingredient_addition

    def initialize(original_query, options = {})
      @original_query = original_query
      @dictionary = options.fetch(:dictionary, Ingreedy.current_dictionary)
    end

    def parse
      super(original_query)
    end

    private

    attr_reader :dictionary, :original_query

    def amount_parser
      AmountParser.new(dictionary: dictionary)
    end

    def prepositions
      dictionary.prepositions
    end

    def unit_matches
      @unit_matches ||= original_query.
                        scan(unit_variation_mapper.regexp).
                        sort_by(&:length).
                        reverse
    end

    def unit_variation_mapper
      UnitVariationMapper.new(dictionary: dictionary)
    end
  end
end