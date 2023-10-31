class RipleyTool

  attr_accessor :name,
                :account,
                :dev_key,
                :tool_id

  def initialize(name, account=nil, dev_key=nil, tool_id=nil)
    @name = name
    @account = account
    @dev_key = dev_key
    @tool_id = tool_id
  end

  TOOLS = [
    ADD_USER = new('Find a Person to Add (LTI 1.3)', Utils.canvas_uc_berkeley_sub_account),
    MANAGE_SITE = new('Manage Sites (LTI 1.3)', Utils.canvas_uc_berkeley_sub_account),
    E_GRADES = new('Download E-Grades (LTI 1.3)', Utils.canvas_official_courses_sub_account),
    MAILING_LIST = new('Mailing List (LTI 1.3)', Utils.canvas_official_courses_sub_account),
    MAILING_LISTS = new('Mailing Lists (LTI 1.3)', Utils.canvas_admin_sub_account),
    NEWT = new('Grade Distribution (LTI 1.3)'),
    ROSTER_PHOTOS = new('Roster Photos', Utils.canvas_official_courses_sub_account),
    USER_PROVISIONING = new('User Provisioning (LTI 1.3)', Utils.canvas_uc_berkeley_sub_account)
  ]

end
