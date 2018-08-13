class User

  attr_accessor :uid, :sis_id, :canvas_id, :suitec_id, :role, :status, :username, :first_name, :last_name, :full_name, :email, :tests, :assets

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
