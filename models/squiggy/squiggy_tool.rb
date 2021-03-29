class SquiggyTool

  attr_accessor :name, :xml

  def initialize(name, xml)
    @name = name
    @xml = xml
  end

  TOOLS = [
    ASSET_LIBRARY = new('Asset Library', '/lti/cartridge/asset_library.xml'),
    ENGAGEMENT_INDEX = new('Engagement Index', '/lti/cartridge/engagement_index.xml')
  ]

end
