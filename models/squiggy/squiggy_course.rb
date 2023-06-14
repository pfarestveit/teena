class SquiggyCourse < Course

  attr_accessor :asset_library_url,
                :is_copy,
                :engagement_index_url,
                :impact_studio_url,
                :lti_tools,
                :roster,
                :squiggy_id,
                :whiteboards_url

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
