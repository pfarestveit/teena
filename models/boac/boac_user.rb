class BOACUser < User

  attr_accessor :active,
                :advisor_roles,
                :can_access_canvas_data,
                :depts,
                :is_admin,
                :is_blocked

end
