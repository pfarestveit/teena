class CourseSite

  attr_accessor :abbreviation,
                :id,
                :created_date

  def initialize(site_data)
    site_data.each { |k, v| public_send("#{k}=", v) }
  end

end
