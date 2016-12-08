class User

  attr_accessor :uid, :username, :full_name, :email, :role, :canvas_id, :tests, :assets

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
  end

end
