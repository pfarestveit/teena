class User

  attr_accessor :uid,
                :sis_id,
                :canvas_id,
                :squiggy_id,
                :role,
                :sections,
                :status,
                :username,
                :first_name,
                :last_name,
                :full_name,
                :email,
                :assets,
                :tests

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
    @sections ||= []
  end

end
