class RipleyTool

  attr_accessor :name,
                :account,
                :dev_key,
                :navigation,
                :path,
                :tool_id,
                :dev_key_name

  def initialize(name, path, navigation, account=nil, dev_key=nil, tool_id=nil, dev_key_name=nil)
    @name = name
    @account = account
    @dev_key = dev_key
    @navigation = navigation
    @path = path
    @tool_id = tool_id
    @dev_key_name = dev_key_name
  end

  TOOLS = [
    ADD_USER = new('Find a Person to Add', 'add_user', 'course_navigation', Utils.canvas_uc_berkeley_sub_account),
    MANAGE_SITES = new('Create & Manage Sites', 'manage_sites', 'user_navigation', Utils.canvas_uc_berkeley_sub_account, nil, nil, 'Manage Sites'),
    E_GRADES = new('Download E-Grades', 'export_grade', 'course_navigation', Utils.canvas_official_courses_sub_account),
    MAILING_LIST = new('Mailing List', 'mailing_list', 'course_navigation', Utils.canvas_official_courses_sub_account),
    MAILING_LISTS = new('Mailing Lists', 'mailing_lists', 'account_navigation', Utils.canvas_admin_sub_account),
    NEWT = new('Grade Distribution', 'grade_distribution', 'course_navigation', Utils.canvas_uc_berkeley_sub_account),
    ROSTER_PHOTOS = new('Roster Photos', 'roster_photos', 'course_navigation', Utils.canvas_official_courses_sub_account),
    USER_PROVISIONING = new('User Provisioning', 'provision_user', 'account_navigation', Utils.canvas_uc_berkeley_sub_account)
  ]

end
