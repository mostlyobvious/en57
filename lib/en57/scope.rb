# frozen_string_literal: true

module En57
  class EmptyScope
    def to_query = Query.all
  end

  class MergedScope
    def initialize(repository:, query:)
      @repository = repository
      @query = query
    end

    def each(&block)
      return enum_for unless block

      @repository.read(@query).each { |event, _position| yield event }
    end

    def each_with_position(&block)
      return enum_for(__method__) unless block

      @repository.read(@query).each do |event, position|
        yield event, position
      end
    end

    def to_query = @query

    def or(other)
      self.class.new(repository: @repository, query: @query.or(other.to_query))
    end
    alias_method :|, :or
  end

  class Scope
    def initialize(repository, query)
      @repository = repository
      @query = query
    end

    def each(&block)
      return enum_for unless block

      @repository.read(@query).each { |event, _position| yield event }
    end

    def each_with_position(&block)
      return enum_for(__method__) unless block

      @repository.read(@query).each do |event, position|
        yield event, position
      end
    end

    def to_query = @query

    def with_tag(*tags)
      self.class.new(
        @repository,
        @query.refine_last { |item| item.with_tags(tags) },
      )
    end

    def of_type(*types)
      self.class.new(
        @repository,
        @query.refine_last { |item| item.with_types(types) },
      )
    end

    def after(position)
      self.class.new(
        @repository,
        @query.refine_last { |item| item.with_after(position) },
      )
    end

    def or(other)
      MergedScope.new(repository: @repository, query: @query.or(other.to_query))
    end
    alias_method :|, :or
  end
end
