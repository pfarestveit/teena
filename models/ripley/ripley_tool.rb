class RipleyTool

  attr_accessor :name,
                :account,
                :dev_key,
                :navigation,
                :path,
                :tool_id

  def initialize(name, path, navigation, account=nil, dev_key=nil, tool_id=nil)
    @name = name
    @account = account
    @dev_key = dev_key
    @navigation = navigation
    @path = path
    @tool_id = tool_id
  end

  TOOLS = [
    ADD_USER = new('Find a Person to Add (LTI 1.3)', 'add_user', 'course_navigation', Utils.canvas_uc_berkeley_sub_account),
    MANAGE_SITES = new('Manage Sites (LTI 1.3)', 'manage_sites', 'user_navigation', Utils.canvas_uc_berkeley_sub_account),
    E_GRADES = new('Download E-Grades (LTI 1.3)', 'export_grade', 'course_navigation', Utils.canvas_official_courses_sub_account),
    MAILING_LIST = new('Mailing List (LTI 1.3)', 'mailing_list', 'course_navigation', Utils.canvas_official_courses_sub_account),
    MAILING_LISTS = new('Mailing Lists (LTI 1.3)', 'mailing_lists', 'account_navigation', Utils.canvas_admin_sub_account),
    NEWT = new('Grade Distribution', 'grade_distribution', 'course_navigation'),
    ROSTER_PHOTOS = new('Roster Photos', 'roster_photos', 'course_navigation', Utils.canvas_official_courses_sub_account),
    USER_PROVISIONING = new('User Provisioning (LTI 1.3)', 'provision_user', 'account_navigation', Utils.canvas_uc_berkeley_sub_account)
  ]

end
