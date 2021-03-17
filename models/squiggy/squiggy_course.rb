class SquiggyCourse < Course

  attr_accessor :asset_library_url,
                :engagement_index_url,
                :lti_tools,
                :roster,
                :squiggy_id

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
