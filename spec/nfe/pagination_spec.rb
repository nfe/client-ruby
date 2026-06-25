# frozen_string_literal: true

RSpec.describe Nfe::ListPage do
  describe ".from_page" do
    subject(:page) { described_class.from_page(page_index: 0, page_count: 5, total: 42) }

    it "fills the page-style fields" do
      expect(page.page_index).to eq(0)
      expect(page.page_count).to eq(5)
      expect(page.total).to eq(42)
    end

    it "leaves the cursor fields nil" do
      expect(page.starting_after).to be_nil
      expect(page.ending_before).to be_nil
    end
  end

  describe ".from_cursor" do
    subject(:page) { described_class.from_cursor(starting_after: "a", ending_before: "z", total: 7) }

    it "fills the cursor-style fields" do
      expect(page.starting_after).to eq("a")
      expect(page.ending_before).to eq("z")
      expect(page.total).to eq(7)
    end

    it "leaves page_index/page_count nil" do
      expect(page.page_index).to be_nil
      expect(page.page_count).to be_nil
    end
  end

  it "defaults every field to nil" do
    page = described_class.new

    expect([page.page_index, page.page_count, page.starting_after, page.ending_before, page.total]).to all(be_nil)
  end

  describe Nfe::ListResponse do
    it "carries data intact alongside a page-style page" do
      response = described_class.new(data: %w[a b c], page: Nfe::ListPage.from_page(page_index: 0, page_count: 1))

      expect(response.data).to eq(%w[a b c])
      expect(response.page.page_index).to eq(0)
    end

    it "carries data intact alongside a cursor-style page" do
      response = described_class.new(data: [1, 2], page: Nfe::ListPage.from_cursor(starting_after: "x"))

      expect(response.data).to eq([1, 2])
      expect(response.page.starting_after).to eq("x")
      expect(response.page.page_index).to be_nil
    end

    it "defaults data to an empty array and page to nil" do
      response = described_class.new

      expect(response.data).to eq([])
      expect(response.page).to be_nil
    end
  end
end
