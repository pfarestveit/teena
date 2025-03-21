class User

  attr_accessor :uid,
                :sis_id,
                :canvas_id,
                :demographics,
                :role,
                :role_code,
                :sections,
                :status,
                :username,
                :first_name,
                :last_name,
                :full_name,
                :email,
                :tests

  def initialize(test_data)
    test_data.each { |k, v| public_send("#{k}=", v) }
    @sections ||= []
    @demographics ||= {}
  end

end
