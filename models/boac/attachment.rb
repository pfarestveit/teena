class Attachment

  attr_accessor :sis_file_name,
                :user_file_name,
                :display_file_name

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
