require_relative 'spec_helper'

class OecUtils

  include Logging

  @config = Utils.config

  def self.base_url(args = nil)
    (args && args.include?('qa')) ? 'https://course-evaluations-qa.berkeley.edu' : 'https://course-evaluations.berkeley.edu'
  end

  def self.create_results_file
    output_dir = File.join(ENV['HOME'], 'selenium-files')
    output_file = 'data_source_update_results.log'
    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
    file = File.join(output_dir, output_file)
    File.open(file, 'w') { |f| f.puts 'Results of OEC data source update script run:' }
    file
  end

  def self.log_results(file, result, e = nil)
    puts result
    puts "#{e.message}\n#{e.backtrace}" if e
    File.open(file, 'a') do |f|
      f.puts "\n => #{result}"
      f.puts "\n#{e.message}\n#{e.backtrace}" if e
    end
  end

  # Returns identifiers for a configured OEC test user
  # @return [Hash]
  def self.oec_user
    {
      first_name: @config['oec']['first_name'],
      last_name: @config['oec']['last_name'],
      uid: @config['oec']['uid'],
      sis_id: @config['oec']['sis_id'],
      email: @config['oec']['email']
    }
  end

  # Returns the expected location of the folder containing sub-dirs and CSVs for the configured term code
  # @return [String]
  def self.term_folder
    File.join(ENV['HOME'], "/OEC/#{@config['oec']['term']}")
  end

  # Edits data in the merged course confirmations file to maximize the number of rows where 'evaluate' can be set to 'yes' and pass
  # validation. Not intended to replicate edits by department admins, only to maximize the data that can reasonably be included in
  # validation and publishing.
  def self.prepare_merged_confirmations
    file_name = File.join("#{term_folder}", '/Step 3 preflight merge/Merged course confirmations.csv')

    # Read the existing file
    initial_csv = CSV.read(file_name, headers: true)

    # Create a new one to replace it
    CSV.open(file_name, 'wb') do |updated_csv|
      updated_csv << initial_csv.headers

      # Edit specific data on each row
      initial_csv.each do |r|
        logger.info "Checking a course instructor pairing for #{r['COURSE_ID']}-#{r['LDAP_UID']}"

        # Fill in missing instructors with the configured OEC user
        user = oec_user
        if r['LAST_NAME'].nil?
          r['LDAP_UID'] = user[:uid]
          r['SIS_ID'] = user[:sis_id]
          r['FIRST_NAME'] = user[:first_name]
          r['LAST_NAME'] = user[:last_name]
          r['EMAIL_ADDRESS'] = user[:email]
        end

        # Exclude instructors without email (adjusting the data is complicated) and one-day modular courses (not evaluated anyway)
        unless r['EMAIL_ADDRESS'].nil? || (r['START_DATE'] == r['END_DATE'])  || (r['CROSS_LISTED_FLAG'] == 'RM SHARE')

          # Make sure the right department forms are set. FSSEM and BIOLOGY follow their own rules, so ignore them.
          unless r['DEPT_FORM'].nil? || r['DEPT_FORM'] == 'FSSEM' || r['DEPT_NAME'] == 'BIOLOGY' || r['DEPT_FORM'] == 'CALTEACH'
            dept = OECDepartments::DEPARTMENTS.find { |d| d.dept_code == r['DEPT_NAME'] }
            r['DEPT_FORM'] = dept.form_code
          end

          # Set empty evaluation types to 'WRIT' or 'F', though some Fs will cause validation errors
          if r['EVALUATION_TYPE'].nil?
            (r['DEPT_FORM'] == 'SPANISH') ? r['EVALUATION_TYPE'] = 'WRIT' : r['EVALUATION_TYPE'] = 'F'
          end

          # Set department forms for cross-listed courses
          if r['CROSS_LISTED_FLAG'] == 'Y'
            cross_listed_name = r['CROSS_LISTED_NAME']
            participating_listing_depts = OECDepartments::DEPARTMENTS.map { |d| d.form_code if cross_listed_name && cross_listed_name.include?(d.dept_code) }
            participating_listing_depts.compact!.sort!
            logger.debug "Cross-listed name is #{cross_listed_name}, and participating depts are #{participating_listing_depts}"
            r['DEPT_FORM'] = participating_listing_depts.first
          end

          # The data will probably pass validation, so set 'evaluate' to 'yes'
          r['EVALUATE'] = 'Y'

        end

        updated_csv << r.fields

      end
    end
  end
end
