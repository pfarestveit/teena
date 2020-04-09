class BOACUser < User

  attr_accessor :active,
                :dept_memberships,
                :can_access_advising_data,
                :can_access_canvas_data,
                :depts,
                :is_admin,
                :is_blocked,
                :is_sir

end
