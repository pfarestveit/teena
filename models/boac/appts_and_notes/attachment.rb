class Attachment

  attr_accessor :id,
                :deleted_at,
                :file_name,
                :sis_file_name,
                :file_size

  def initialize(data)
    data.each { |k, v| public_send("#{k}=", v) }
  end

end
