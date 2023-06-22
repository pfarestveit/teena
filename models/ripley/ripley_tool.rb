class RipleyTool

  attr_accessor :name,
                :account,
                :dev_key,
                :tool_id

  def initialize(name, account, dev_key=nil, tool_id=nil)
    @name = name
    @account = account
    @dev_key = dev_key
    @tool_id = tool_id
  end

  TOOLS = [
    ADD_USER = new('Find a Person to Add', Utils.canvas_uc_berkeley_sub_account),
    CREATE_SITE = new('Create a Site', Utils.canvas_uc_berkeley_sub_account),
    E_GRADES = new('Download E-Grades', Utils.canvas_official_courses_sub_account),
    MAILING_LIST = new('Mailing List', Utils.canvas_official_courses_sub_account),
    MAILING_LISTS = new('Mailing Lists', Utils.canvas_admin_sub_account),
    OFFICIAL_SECTIONS = new('Manage Official Sections', Utils.canvas_official_courses_sub_account),
    ROSTER_PHOTOS = new('Roster Photos', Utils.canvas_official_courses_sub_account),
    USER_PROVISIONING = new('User Provisioning', Utils.canvas_uc_berkeley_sub_account)
  ]

end
