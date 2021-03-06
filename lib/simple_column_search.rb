require 'rubygems'
require 'active_record'

module SimpleColumnSearch
  # Adds a Model.search('term1 term2') method that searches across SEARCH_COLUMNS
  # for ANDed TERMS ORed across columns.
  #
  #  class User
  #    simple_column_search :first_name, :last_name
  #  end
  #
  #  User.search('elijah')          # => anyone with first or last name elijah
  #  User.search('miller')          # => anyone with first or last name miller
  #  User.search('elijah miller')
  #    # => anyone with first or last name elijah AND
  #    #    anyone with first or last name miller
  def simple_column_search(*args)
    options = args.extract_options!
    columns = args

    options[:match] ||= :start
    options[:name] ||= 'search'

    # Test options at create time
    get_simple_column_pattern(options[:match], 'test')

    # PostgreSQL LIKE is case-sensitive, use ILIKE for case-insensitive
    like = connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"
    # Determine if ActiveRecord 3
    if ActiveRecord::VERSION::MAJOR == 3
      scope options[:name], lambda { |terms|
        conditions = terms.split.inject(where(nil)) do |acc, term|
          pattern = get_simple_column_pattern options[:match], term
          acc.where(columns.collect { |column| "#{table_name}.#{column} #{like} :pattern" }.join(' OR '), { :pattern => pattern })
        end
      }
    else
      named_scope options[:name], lambda { |terms|
        conditions = terms.split.inject(nil) do |acc, term|
          pattern = get_simple_column_pattern options[:match], term
          merge_conditions acc, [columns.collect { |column| "#{table_name}.#{column} #{like} :pattern" }.join(' OR '), { :pattern => pattern }]
        end
        { :conditions => conditions }
      }
    end

  end

  def get_simple_column_pattern(match, term)
    case(match)
    when :exact
      term
    when :start
      term + '%'
    when :middle
      '%' + term + '%'
    when :end
      '%' + term
    else
      raise InvalidMatcher, "Unexpected match type: #{match}"
    end
  end

  class InvalidMatcher < StandardError; end

end

ActiveRecord::Base.extend(SimpleColumnSearch)