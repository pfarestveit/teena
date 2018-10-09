class LtiTools

  attr_accessor :name, :xml

  def initialize(name, xml)
    @name = name
    @xml = xml
  end

  ASSET_LIBRARY = new('Asset Library', '/lti/assetlibrary.xml')
  ENGAGEMENT_INDEX = new('Engagement Index', '/lti/engagementindex.xml')
  WHITEBOARDS = new('Whiteboards', '/lti/whiteboards.xml')
  IMPACT_STUDIO = new('Impact Studio', '/lti/dashboard.xml')

  class << self
    private :new
  end

end
