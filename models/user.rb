class User

  attr_accessor :uid, :sis_id, :username, :full_name, :email, :role, :canvas_id, :tests, :assets, :status

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
