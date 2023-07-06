class BOACUser < User

  attr_accessor :active,
                :alert_count,
                :alt_names,
                :degree_progress_perm,
                :degree_progress_automated,
                :dept_memberships,
                :can_access_advising_data,
                :can_access_canvas_data,
                :depts,
                :is_admin,
                :is_blocked,
                :is_sir

end
