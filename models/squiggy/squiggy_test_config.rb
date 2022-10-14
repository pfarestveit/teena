class SquiggyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :course

  CONFIG = SquiggyUtils.config

  def initialize(test_name)
    super
    @base_url = SquiggyUtils.config['base_url']

    @course = SquiggyCourse.new title: "#{@id} #{test_name}", code: "#{@id} #{test_name}"
    @course.lti_tools = SquiggyTool::TOOLS
    section_1 = Section.new label: "WBL 001 #{@id}", sis_id: "WBL 001 #{@id}"
    section_2 = Section.new label: "WBL 002 #{@id}", sis_id: "WBL 002 #{@id}"
    @test.course.sections = [section_1, section_2]

    set_test_user_data File.join(Utils.config_dir, 'test-data-squiggy.json')
    @course.roster = set_test_users(test_name, SquiggyUser)
    @course.roster.each do |member, i|
      member.assets = member.assets&.map do |a|
        asset = SquiggyAsset.new a
        asset.title = "#{asset.title} #{id}"
        asset.owner = member
        if asset.file_name
          asset.size = File.size(File.join(Utils.config_dir, "assets/#{asset.file_name}"))
        end
        asset
      end
      member.sections = i.odd? ? [section_1] : [section_2]
    end
  end

end
