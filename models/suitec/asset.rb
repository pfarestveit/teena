class Asset

  attr_accessor :id, :type, :url, :file_name, :title, :description, :category, :preview

  def initialize(asset_data)
    asset_data.each { |k, v| public_send("#{k}=", v) }
  end

end
