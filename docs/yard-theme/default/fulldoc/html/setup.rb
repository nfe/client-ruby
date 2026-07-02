# frozen_string_literal: true
# NFE.io YARD theme: append the brand stylesheet to the default ones so it loads
# last (and thus overrides the defaults) on both the main pages and the nav frame.
def stylesheets
  super + %w[css/nfeio.css]
end

def stylesheets_full_list
  super + %w[css/nfeio.css]
end
