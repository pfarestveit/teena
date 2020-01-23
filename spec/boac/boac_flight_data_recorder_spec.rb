require_relative '../../util/spec_helper'

include Logging

all_users = BOACUtils.get_authorized_users
all_non_admin_users = all_users.reject &:is_admin

admin = all_users.find &:is_admin
director = all_non_admin_users.find { |u| u.advisor_roles.find &:is_director }
advisor = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_advisor).reject(&:is_director).any? }
scheduler = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_scheduler).reject(&:is_director).reject(&:is_advisor).any? }

logger.warn "Admin UID #{admin.uid}, director UID #{director.uid}, advisor UID #{advisor.uid}, scheduler UID #{scheduler.uid}"

describe 'BOA flight data recorder' do

  context 'when the user is an admin' do

    it 'hides the complete notes report by default'
    it 'allows the user to view the complete notes report'
    it 'shows the total number of notes imported from the SIS'
    it 'shows the total number of notes imported from the ASC'
    it 'shows the total number of notes imported from the CEEE'

    context 'viewing the created-in-BOA notes report' do
      it 'shows the total number of notes'
      it 'shows the total distinct note authors'
      it 'shows the percentage of notes with attachments'
      it 'shows the percentage of notes with topics'
    end

    BOACDepartments::DEPARTMENTS.each do |dept|

      it "allows the user to filter users by #{dept.name}"

      all_users.select { |u| u.depts.include? dept }.each do |user|

        it "shows a link to the directory for #{dept.name} UID #{user.uid}"
        it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}"
        it "shows the last login date for #{dept.name} UID #{user.uid}"

        user.advisor_roles.each do |role|

          it "shows the #{dept.name} UID #{user.uid} department role #{role.inspect}"

        end
      end
    end
  end

  context 'when the user is a director' do

    it "only shows data for UID #{director.uid} departments #{director.advisor_roles.select(&:is_director).map(&:dept).map(&:name)}"
    it 'hides the complete notes report by default'
    it 'allows the user to view the complete notes report'

    director.advisor_roles.select(&:is_director).map(&:dept).each do |dept|

      it "allows the user to filter users by #{dept.name}"

      all_non_admin_users.select { |u| u.depts.include? dept }.each do |user|

        it "shows a link to the directory for #{dept.name} UID #{user.uid}"
        it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}"
        it "shows the last login date for #{dept.name} UID #{user.uid}"

      end
    end
  end

  context 'when the user is an advisor' do

    it 'offers no link in the header'
    it 'prevents the user hitting the page'

  end

  context 'when the user is a scheduler' do

    it 'offers no link in the header'
    it 'prevents the user hitting the page'

  end
end
