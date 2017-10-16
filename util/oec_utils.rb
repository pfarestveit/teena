require_relative 'spec_helper'

class OecUtils

  include Logging

  @config = Utils.config

  def self.base_url(args)
    args.include?('qa') ? 'https://course-evaluations-qa.berkeley.edu' : 'https://course-evaluations.berkeley.edu'
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

  # Returns departments that should be included in a given supervisors file but are missing
  # @param file_name [String]
  # @return [Array<String>]
  def self.missing_supervisor_depts(file_name)
    initial_csv = CSV.read(file_name, headers: true)
    depts_present = []
    initial_csv.each do |r|
      1.upto(10) { |i| depts_present << r["DEPT_NAME_#{i}"] if r["DEPT_NAME_#{i}"]}
    end
    depts_present.uniq!
    depts_needed = OECDepartments::DEPARTMENTS.map { |d| d.form_code }
    depts_needed.compact!
    depts_needed.uniq!
    depts_missing = depts_needed - depts_present
    logger.debug "Departments missing: #{depts_missing}"
    depts_missing
  end

  # Returns departments that are missing from the supervisors override file, which will end up missing in the merged file too.
  # @return [Array<String>]
  def self.missing_supervisor_override_depts
    missing_supervisor_depts File.join("#{term_folder}", 'Overrides/supervisors.csv')
  end

  # Returns departments that are missing from the merged supervisors file, which will cause validation errors.
  # @return [Array<String>]
  def self.missing_supervisor_merged_depts
    missing_supervisor_depts File.join("#{term_folder}", 'Step 3 preflight merge/Merged supervisor confirmations.csv')
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

        # Exclude room shares and instructors without email (adjusting the data is complicated) and one-day modular courses and LEGALST (not evaluated anyway)
        unless r['EMAIL_ADDRESS'].nil? || (r['CROSS_LISTED_FLAG'] == 'RM SHARE') || (r['START_DATE'] == r['END_DATE']) || (r['DEPT_NAME'] == 'LEGALST')

          # Make sure the right department forms are set. FSSEM and BIOLOGY follow their own rules, so ignore them.
          unless r['DEPT_FORM'].nil? || r['DEPT_FORM'] == 'FSSEM' || r['DEPT_NAME'] == 'BIOLOGY'
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
            participating_listing_depts = OECDepartments::DEPARTMENTS.map { |d| d.form_code if cross_listed_name.include?(d.dept_code) }
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
