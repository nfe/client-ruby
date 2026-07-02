# frozen_string_literal: true

module Nfe
  # Pagination metadata for a list response. NFE.io endpoints paginate in one
  # of two shapes; each resource populates only the half relevant to it:
  #
  # * page-style — +page_index+ / +page_count+ (cursor fields nil)
  # * cursor-style — +starting_after+ / +ending_before+ (+page_index+ nil)
  #
  # +total+ is optional and may be present in either shape.
  class ListPage < Data.define(:page_index, :page_count, :starting_after, :ending_before, :total)
    # @return [Nfe::ListPage] a page-style page with cursor fields left nil.
    def self.from_page(page_index: nil, page_count: nil, total: nil)
      new(page_index: page_index, page_count: page_count,
          starting_after: nil, ending_before: nil, total: total)
    end

    # @return [Nfe::ListPage] a cursor-style page with +page_index+/+page_count+ nil.
    def self.from_cursor(starting_after: nil, ending_before: nil, total: nil)
      new(page_index: nil, page_count: nil,
          starting_after: starting_after, ending_before: ending_before, total: total)
    end

    def initialize(page_index: nil, page_count: nil, starting_after: nil,
                   ending_before: nil, total: nil)
      super
    end
  end

  # A list of hydrated DTOs (+data+) plus its pagination metadata (+page+).
  # +data+ is iterated identically regardless of pagination shape.
  #
  # Includes +Enumerable+ (delegating +each+ to +data+), so a list response is
  # usable directly anywhere an Enumerable is expected — +map+, +select+,
  # +each_with_index+, ... — without first reaching into +data+.
  class ListResponse < Data.define(:data, :page)
    include Enumerable

    def initialize(data: [], page: nil)
      super
    end

    # Iterate the hydrated DTOs in +data+.
    #
    # @yieldparam item each hydrated DTO.
    # @return [Enumerator] when called without a block.
    def each(&)
      return enum_for(:each) unless block_given?

      data.each(&)
    end
  end
end
