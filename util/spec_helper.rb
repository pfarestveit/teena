require 'rspec'
require 'rspec/core/rake_task'
require 'logger'
require "base64"
require 'csv'
require 'json'
require 'nokogiri'
require 'selenium-webdriver'
require 'fileutils'
require 'pg'
require 'time'
require 'yaml'

require_relative '../logging'
require_relative '../models/user'
require_relative '../models/email'
require_relative '../models/test_config'
require_relative '../models/term'
require_relative '../models/course_site'
require_relative '../models/course_site_roles'
require_relative '../models/course'
require_relative '../models/section'
require_relative '../models/section_enrollment'
require_relative '../models/ripley/instructor_and_role'
require_relative '../models/canvas/announcement'
require_relative '../models/canvas/assignment'
require_relative '../models/canvas/discussion'
require_relative '../models/canvas/group_set'
require_relative '../models/canvas/group'
require_relative '../models/squiggy/squiggy_activity'
require_relative '../models/squiggy/squiggy_asset'
require_relative '../models/squiggy/squiggy_category'
require_relative '../models/squiggy/squiggy_comment'
require_relative '../models/squiggy/squiggy_tool'
require_relative '../models/squiggy/squiggy_user'
require_relative '../models/squiggy/squiggy_site'
require_relative '../models/squiggy/squiggy_whiteboard'

require_relative 'utils'
require_relative 'nessie_utils'
require_relative 'oec_utils'
require_relative 'ripley_utils'
require_relative '../models/ripley/ripley_job'
require_relative '../models/ripley/ripley_tool'
require_relative 'squiggy_utils'
require_relative '../pages/element'
require_relative '../pages/page_object'
require_relative '../pages/page'
require_relative '../pages/oec/blue_page'
require_relative '../pages/cal_net_page'

require_relative '../pages/canvas/canvas_api_page'
require_relative '../pages/canvas/canvas_people_page'
require_relative '../pages/canvas/canvas_page'
require_relative '../pages/canvas/canvas_assignments_page'
require_relative '../pages/canvas/canvas_announce_discuss_page'
require_relative '../pages/canvas/canvas_grades_page'
require_relative '../pages/canvas/canvas_groups_page'

require_relative '../models/ripley/ripley_test_config'
require_relative '../pages/ripley/ripley_pages'
require_relative '../pages/ripley/ripley_course_sections_module'
require_relative '../pages/ripley/ripley_splash_page'
require_relative '../pages/ripley/ripley_add_user_page'
require_relative '../pages/ripley/ripley_admin_page'
require_relative '../pages/ripley/ripley_site_creation_page'
require_relative '../pages/ripley/ripley_create_course_site_page'
require_relative '../pages/ripley/ripley_create_project_site_page'
require_relative '../pages/ripley/ripley_grade_distribution_page'
require_relative '../pages/ripley/ripley_e_grades_page'
require_relative '../pages/ripley/ripley_mailing_list_page'
require_relative '../pages/ripley/ripley_mailing_lists_page'
require_relative '../pages/ripley/ripley_official_sections_page'
require_relative '../pages/ripley/ripley_roster_photos_page'
require_relative '../pages/ripley/ripley_user_provisioning_page'

require_relative '../models/squiggy/squiggy_test_config'
require_relative '../pages/squiggy/squiggy_pages'
require_relative '../pages/squiggy/squiggy_login_page'
require_relative '../pages/squiggy/squiggy_asset_library_search_form'
require_relative '../pages/squiggy/squiggy_asset_library_metadata_form'
require_relative '../pages/squiggy/squiggy_asset_library_list_view_page'
require_relative '../pages/squiggy/squiggy_whiteboard_edit_form'
require_relative '../pages/squiggy/squiggy_asset_library_detail_page'
require_relative '../pages/squiggy/squiggy_asset_library_manage_assets_page'
require_relative '../pages/squiggy/squiggy_engagement_index_page'
require_relative '../pages/squiggy/squiggy_whiteboards_page'
require_relative '../pages/squiggy/squiggy_whiteboard_page'
require_relative '../pages/squiggy/squiggy_impact_studio_page'
