require_relative '../util/spec_helper'

begin

  include Logging

  csv_1_path = ENV['CSV_1']
  csv_2_path = ENV['CSV_2']

  csv_1 = CSV.read(csv_1_path).each.to_a
  csv_2 = CSV.read(csv_2_path).each.to_a

  unique_to_1 = csv_1 - csv_2
  unique_to_2 = csv_2 - csv_1
  logger.warn "There are #{unique_to_1.length} rows in CSV_1 that are not in CSV_2"
  logger.warn "There are #{unique_to_2.length} rows in CSV_2 that are not in CSV_1"

  CSV.open("#{Utils.initialize_test_output_dir}/unique-to-csv-1-#{csv_1_path.split('/').last}", 'w') do |csv|
    csv << csv_1.first
    unique_to_1.each { |row| csv << row }
  end

  CSV.open("#{Utils.initialize_test_output_dir}/unique-to-csv-2-#{csv_2_path.split('/').last}", 'w') do |csv|
    csv << csv_2.first
    unique_to_2.each { |row| csv << row }
  end

end
