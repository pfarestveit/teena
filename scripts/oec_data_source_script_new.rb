require_relative '../util/spec_helper'

begin

  include Logging

  logger.info 'Beginning OEC data source update script'
  args = ARGV.to_s
  campus_data_sources = %w(Campus_Courses Campus_Supervisors Campus_Instructors Campus_Students Campus_Course_Supervisors Campus_Course_Instructors Campus_Course_Students)
  extension_data_sources = Dir[File.join(ENV['HOME'], 'selenium-files/*.csv')] + Dir[File.join(ENV['HOME'], 'selenium-files/*.CSV')]

  results_file = OecUtils.create_results_file
  driver = Utils.launch_browser
  @blue = Page::BluePage.new driver
  @cal_net = Page::CalNetPage.new driver

  if args.empty?

    OecUtils.log_results(results_file, "#{Time.now} - You didn't tell me what data sources to update. I quit.")

  else

    @blue.wait_for_log_in(args, @cal_net)

    # CAMPUS DATA SOURCES
    if args.include? 'campus'
      campus_data_sources.each do |data_source|
        begin
          @blue.find_and_edit_source(args, data_source)
          @blue.connect_source
          @blue.apply_and_import_source
          OecUtils.log_results(results_file, "#{Time.now} - Update succeeded for #{data_source}")
        rescue => e
          OecUtils.log_results(results_file, "#{Time.now} - Encountered an error with data source '#{data_source}'. Update failed.", e)
        end
      end
    end

    # EXTENSION DATA SOURCES
    if args.include? 'extension'
      if extension_data_sources.any?
        extension_data_sources.each do |file|
          begin
            @blue.find_and_edit_source(args, (data_source = File.basename(file)[0..-5]))
            @blue.upload_file file
            @blue.apply_and_import_source
            OecUtils.log_results(results_file, "#{Time.now} - Update succeeded for #{data_source}")
          rescue => e
            OecUtils.log_results(results_file, "#{Time.now} - Encountered an error with data source '#{data_source}'. Update failed.", e)
          end
        end
      else
        logger.error 'There are no files to upload!'
        OecUtils.log_results(results_file, 'No files were uploaded for any data sources')
      end
    end
  end

rescue => e
  OecUtils.log_results(results_file, "#{Time.now} - Encountered an error initializing the script. No data sources were updated", e)
ensure
  Utils.quit_browser driver
end
