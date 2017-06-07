class Configuration
  attr_accessor :url, :user_agent

  def initialize
    @url = "https://api.nfe.io"
    @user_agent = "NFe.io Ruby Client v#{Nfe::VERSION}"
  end
end
