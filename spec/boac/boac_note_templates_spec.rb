require_relative '../../util/spec_helper'

describe 'BOA note templates' do

  before do
    @test = BOACTestConfig.new
    @test.note_templates
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth @test.advisor
  end

  after { Utils.quit_browser @driver }

  it 'can be deleted' do
    # click new note
    # click template button
    # delete all existing templates
  end

  context 'when an advisor has no templates' do

    before do
      # load student page
      # click create new note
      # click advanced note options
      # click template button
    end

    it 'show a "You have no saved templates" message'
  end

  context 'on the student page create-note modal' do

    context 'when an advisor creates a new template' do

      before do
        # click create new template
      end

      it 'require a subject'
      it 'limit a subject to 255 characters'
      it 'require a name'
      it 'allow a body'
      it 'allow topics'
      it 'allow attachments'
      it 'allow a maximum of 5 attachments'

      it 'add the template to the available templates'
      it 'can be applied to a new note'
      it 'save all template metadata to a new note'

    end

    context 'when an advisor edits an existing template' do

      before do
        # load student page
        # click create new note
        # click advanced note options
      end

      it 'require a note subject'
      it 'require a name'
      it 'allow a body'
      it 'allow topics'
      it 'allow attachments'
      it 'allow a maximum of 5 attachments'

      it 'preserve the template among the available templates'
      it 'can be applied to a new note'
      it 'save all template metadata to a new note'

    end

    context 'when an advisor deletes an existing template' do

      before do
        # load student page
        # click create new note
        # click advanced note options
      end

      it 'remove the deleted template from the available templates'

    end
  end

  context 'on the batch note modal' do

    context 'when an advisor creates a new template' do

      before do
        # click create new note
      end

      it 'require a note subject'
      it 'require a name'
      it 'allow a body'
      it 'allow topics'
      it 'allow attachments'
      it 'allow a maximum of 5 attachments'

      it 'add the template to the available templates'
      it 'can be applied to a new note'
      it 'save all template metadata to a new note'

    end

    context 'when an advisor edits an existing template' do

      before do
        # click advanced note options
      end

      it 'require a note subject'
      it 'require a name'
      it 'allow a body'
      it 'allow topics'
      it 'allow attachments'
      it 'allow a maximum of 5 attachments'

      it 'preserve the template among the available templates'
      it 'can be applied to a new note'
      it 'save all template metadata to a new note'

    end

    context 'when an advisor deletes an existing template' do

      before do
        # click advanced note options
      end

      it 'remove the deleted template from the available templates'

    end
  end
end
