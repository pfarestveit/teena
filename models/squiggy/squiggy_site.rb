class SquiggySite < CourseSite

  attr_accessor :asset_library_url,
                :engagement_index_url,
                :impact_studio_url,
                :lti_tools,
                :squiggy_id,
                :whiteboards_url

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
