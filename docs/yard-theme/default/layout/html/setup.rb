# frozen_string_literal: true
# Layout-scope override so the brand stylesheet is linked on every rendered
# object page (the fulldoc-scope override only covers the nav frame + asset copy).
def stylesheets
  super + %w[css/nfeio.css]
end
