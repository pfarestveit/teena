class RipleyJob

  attr_reader :name, :key

  def initialize(name, key)
    @name = name
    @key = key
  end

  JOBS = [
    ADD_GUEST_USERS = new('Add Guest Users', 'add_guest_users'),
    ADD_NEW_USERS = new('Add New Users', 'add_new_users'),
    DELETE_EMAIL_ADDRESSES = new('Bcourses Delete Email Addresses', 'bcourses_refresh_accounts'),
    EXPORT_TERM_ENROLLMENTS = new('Export Term Enrollments', 'export_term_enrollments'),
    HOUSE_KEEPING = new('House Keeping', 'house_keeping'),
    REFRESH_ACCOUNTS = new('Bcourses Refresh Accounts', 'bcourses_refresh_accounts'),
    REFRESH_FULL = new('Bcourses Refresh Full', 'bcourses_refresh_full'),
    REFRESH_INCREMENTAL = new('Bcourses Refresh Incremental', 'bcourses_refresh_incremental'),
    REFRESH_MAILING_LIST = new('Mailing List Refresh', 'mailing_list_refresh'),
    REPORT_LTI_USAGE = new('Lti Usage Report', 'lti_usage_report')
  ]

end
