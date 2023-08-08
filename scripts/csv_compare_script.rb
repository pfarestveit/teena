require_relative '../util/spec_helper'

begin

  include Logging

  inactivate = ENV['INACTIVATE']
  csv_1_path = File.join(Utils.output_dir, "test-output/#{ENV['CSV_1']}.csv")
  csv_2_path = File.join(Utils.output_dir, "test-output/#{ENV['CSV_2']}.csv")

  if inactivate
    csv_1 = CSV.read(csv_1_path, headers: true, header_converters: :symbol)
    csv_1.map { |r| r.to_hash }
    csv_2 = CSV.read(csv_2_path, headers: true, header_converters: :symbol)
    csv_2.map { |r| r.to_hash }

    [csv_1, csv_2].each do |c|
      c.each do |r|
        r[:login_id] = "inactive-#{r[:login_id]}" if r[:status] == 'suspended'
        r[:status] = 'suspended' if r[:login_id][0..8] == 'inactive-'
      end
    end

    csv_1 = csv_1.to_a
    csv_2 = csv_2.to_a
  else
    csv_1 = CSV.read(csv_1_path).each.to_a
    csv_2 = CSV.read(csv_2_path).each.to_a
  end

  [csv_1, csv_2].each do |c|
    c.each { |r| r.map! { |i| i.to_s }}
  end

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
