class SquiggyTool

  attr_accessor :name, :xml

  def initialize(name, xml)
    @name = name
    @xml = xml
  end

  TOOLS = [
    ASSET_LIBRARY = new('Asset Library', '/lti/assetlibrary.xml'),
    ENGAGEMENT_INDEX = new('Engagement Index', '/lti/engagementindex.xml')
  ]

end
