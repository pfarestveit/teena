class SquiggyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :course_site

  CONFIG = SquiggyUtils.config

  def initialize(test_name)
    super
    @base_url = SquiggyUtils.config['base_url']

    @course_site = SquiggySite.new title: "#{@id} #{test_name}",
                                   abbreviation: "#{@id} #{test_name}"
    @course_site.lti_tools = SquiggyTool::TOOLS
    @course_site.site_id = ENV['COURSE_ID']
    unless @course_site.site_id
      section_1 = Section.new label: "WBL 001 #{@id}", sis_id: "WBL 001 #{@id}"
      section_2 = Section.new label: "WBL 002 #{@id}", sis_id: "WBL 002 #{@id}"
      @course_site.sections = [section_1, section_2]
    end

    set_test_user_data File.join(Utils.config_dir, 'test-data-squiggy.json')
    @course_site.manual_members = set_fake_test_users(test_name, SquiggyUser)
    @course_site.manual_members.each_with_index do |member, i|
      member.assets = member.assets&.map do |a|
        asset = SquiggyAsset.new a
        asset.title = "#{asset.title} #{id}"
        asset.owner = member
        if asset.file_name
          asset.size = File.size(File.join(Utils.config_dir, "assets/#{asset.file_name}"))
        end
        asset
      end
      unless @course_site.site_id
        member.sections = i.odd? ? [section_1] : [section_2]
      end
    end
  end

end
