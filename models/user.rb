class User

  attr_accessor :uid,
                :sis_id,
                :canvas_id,
                :role,
                :status,
                :username,
                :first_name,
                :last_name,
                :full_name,
                :email,
                :tests

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
