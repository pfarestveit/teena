describe 'Engagement Index points configuration' do

  SquiggyActivity::ACTIVITIES.each do |squigtivity|
    it "by default shows '#{squigtivity.title}' worth default points"
  end

  it 'allows a teacher to cancel disabling an activity'
  it 'allows a teacher to disable an activity type'
  it 'subtracts points retroactively for a disabled activity'
  it 'removes a disabled activity from the CSV export'
  it 'disabled activities are not visible to a student'
  it 'allows a teacher to cancel re-enabling a disabled activity type'
  it 'allows a teacher to re-enable a disabled activity type'
  it 'adds points retroactively for a re-enabled activity'
  it 'adds a re-enabled activity to the CSV export'
  it 'allows a teacher to change an activity type point value to a new integer'
  it 'allows a teacher to recalculate points retroactively when changing activity type point values'
  it 'recalculates activity points on the CSV export when changing activity type point values'
  it 'allows a student to view the Points Configuration whether or not they share their scores'
  it 'shows a student no editing interface'
end
