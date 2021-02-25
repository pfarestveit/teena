describe 'Canvas assignment sync' do

  it 'is false by default'
  it 'does not include assignments without sync-able submission types'

  context 'when enabled for Assignment 1 but not enabled for Assignment 2' do
    it 'adds assignment submission points to the Engagement Index score for both submissions'
    it 'adds assignment submission activity to the CSV export for both submissions'
    it 'shows the Assignment 1 submission in the Asset Library'
    it 'does not show the Assignment 2 submission in the Asset Library'
  end

  context 'when disabled for Assignment 1 but enabled for Assignment 2' do
    it 'does not alter existing assignment submission points on the Engagement Index score'
    it 'does not alter existing assignment submission activity on the CSV export'
    it 'hides the Assignment 1 submission in the Asset Library'
    it 'shows the Assignment 2 submission in the Asset Library'
  end
end
