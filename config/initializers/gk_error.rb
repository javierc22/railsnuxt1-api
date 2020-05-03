Rails.configuration.to_prepare do
  class GKError < StandardError
  end

  class GKAuthenticationError < StandardError
  end
end