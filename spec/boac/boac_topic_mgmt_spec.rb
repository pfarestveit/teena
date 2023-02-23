require_relative '../../util/spec_helper'

unless ENV['DEPS']

  describe 'A BOAC topic' do

    before(:all) do
      @test = BOACTestConfig.new
      @test.topic_mgmt

      @driver = Utils.launch_browser
      @student = @test.students.shuffle.first
      @topic = Topic.new("Topic test #{@test.id}", true, true)
      @note = Note.new student: @student, subject: "Topic test #{@test.id}"
      @template = NoteTemplate.new(title: "Template #{@test.id}", subject: 'Template subj', body: 'Template body')

      @homepage = BOACHomePage.new @driver
      @pax_manifest = BOACPaxManifestPage.new @driver
      @flight_deck = BOACFlightDeckPage.new @driver
      @student_page = BOACStudentPage.new @driver
      @search_results = BOACSearchResultsPage.new @driver

      @homepage.dev_auth
      @homepage.click_flight_deck_link
    end

    after(:all) do
      Utils.quit_browser @driver
      BOACUtils.hard_delete_topic @topic if @topic.id
      @template.hard_delete_template if @template.id
    end

    context 'creation' do

      it 'requires a label and note selection' do
        @flight_deck.click_create_topic
        expect(@flight_deck.topic_save_button_element.enabled?).to be false
        @flight_deck.enter_topic_label 'foo'
        expect(@flight_deck.topic_save_button_element.enabled?).to be false
        @flight_deck.check_topic_in_notes
        expect(@flight_deck.topic_save_button_element.enabled?).to be true
        @flight_deck.uncheck_topic_in_notes
        expect(@flight_deck.topic_save_button_element.enabled?).to be false
      end

      it 'requires a unique label' do
        existing_topic = Topic::ACADEMIC_PROGRESS
        @flight_deck.enter_topic_label existing_topic.name
        expect(@flight_deck.label_validation_error).to eql("Sorry, the label '#{existing_topic.name}' is assigned to an existing topic.")
        expect(@flight_deck.topic_save_button_element.enabled?).to be false
      end

      it 'can have a label up to 50 characters' do
        long_label = 'A long label ' * 4
        @flight_deck.enter_topic_label long_label[0..49]
        expect(@flight_deck.label_length_validation).to include('(0 left)')
      end

      it('can be canceled') { @flight_deck.click_cancel_topic }
      it('can be saved') { @flight_deck.create_topic @topic }

      it 'can be searched on the Flight Deck' do
        @flight_deck.search_for_topic @topic
        @flight_deck.topic_row(@topic).when_visible 1
      end

      it 'shows the right topic data on the Flight Deck' do
        expect(@flight_deck.topic_deleted? @topic).to be false
        expect(@flight_deck.topic_in_notes @topic).to eql('Yes')
        expect(@flight_deck.topic_in_notes_count @topic).to eql('0')
      end
    end

    context 'editing' do

      it 'can be canceled' do
        @flight_deck.click_edit_topic @topic
        @flight_deck.click_cancel_topic
      end

      it 'requires note selection' do
        @flight_deck.click_edit_topic @topic
        @flight_deck.uncheck_topic_in_notes
        expect(@flight_deck.topic_save_button_element.enabled?).to be false
        @flight_deck.check_topic_in_notes
        expect(@flight_deck.topic_save_button_element.enabled?).to be true
      end
    end

    context 'when it is available to notes' do

      before(:all) do
        @flight_deck.hit_escape
        @flight_deck.log_out
        @homepage.dev_auth @test.advisor
        @homepage.click_create_note_batch
        @homepage.enter_new_note_subject @note
        @homepage.create_template(@template, @note)
      end

      it 'can be selected for an individual note' do
        @student_page.load_page @student
        @student_page.click_create_new_note
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'can be selected for a batch note' do
        @student_page.hit_escape
        @student_page.click_create_note_batch
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'can be selected for a note template' do
        @student_page.click_templates_button
        @student_page.click_edit_template @template
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'is returned in search results for any notes that include the topic' do
        @student_page.load_page @student
        @student_page.create_note(@note, [@topic], nil)
        @student_page.open_adv_search
        @student_page.select_note_topic @topic
        @student_page.click_adv_search_button
        expect(@search_results.note_in_search_result? @note).to be true
      end

      it 'shows its usage in notes' do
        @search_results.log_out
        @homepage.dev_auth
        @homepage.click_flight_deck_link
        @flight_deck.search_for_topic @topic
        expect(@flight_deck.topic_in_notes_count @topic).to eql('1')
      end
    end

    context 'when it is available to notes only' do

      before(:all) do
        @topic.for_appts = false
        @flight_deck.edit_topic @topic
        @flight_deck.log_out
        @homepage.dev_auth @test.advisor
      end

      it 'can be selected for an individual note' do
        @student_page.load_page @student
        @student_page.click_create_new_note
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'can be selected for a batch note' do
        @student_page.hit_escape
        @student_page.click_create_note_batch
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'can be selected for a note template' do
        @student_page.click_templates_button
        @student_page.click_edit_template @template
        expect(@student_page.topic_options).to include(@topic.name)
      end

      it 'is returned in search results for any notes that include the topic' do
        @homepage.load_page
        @homepage.open_adv_search
        @homepage.select_note_topic @topic
        @homepage.click_adv_search_button
        expect(@search_results.note_in_search_result? @note).to be true
      end

      it 'shows its usage in notes' do
        @search_results.log_out
        @homepage.dev_auth
        @homepage.click_flight_deck_link
        @flight_deck.search_for_topic @topic
        expect(@flight_deck.topic_in_notes_count @topic).to eql('1')
      end
    end

    context 'when it is deleted' do

      before(:all) { @flight_deck.delete_topic @topic }

      it('shows as deleted on the Flight Deck') { expect(@flight_deck.topic_deleted? @topic).to be true }

      it 'shows null availability in notes' do
        expect(@flight_deck.topic_in_notes @topic).to eql('—')
      end

      it 'shows its usage in notes' do
        expect(@flight_deck.topic_in_notes_count @topic).to eql('1')
      end

      it 'cannot be selected for an individual note' do
        @flight_deck.log_out
        @homepage.dev_auth @test.advisor
        @student_page.load_page @student
        @student_page.click_create_new_note
        expect(@student_page.topic_options).not_to include(@topic.name)
      end

      it 'cannot be selected for a batch note' do
        @student_page.hit_escape
        @student_page.click_create_note_batch
        expect(@student_page.topic_options).not_to include(@topic.name)
      end

      it 'cannot be selected for a note template' do
        @student_page.click_templates_button
        @student_page.click_edit_template @template
        expect(@student_page.topic_options).not_to include(@topic.name)
      end

      it 'is returned in search results for any notes that include the topic' do
        @homepage.load_page
        @homepage.open_adv_search
        @homepage.select_note_topic @topic
        @homepage.click_adv_search_button
        expect(@search_results.note_in_search_result? @note).to be true
      end
    end

    context 'when it is un-deleted' do

      before(:all) do
        @search_results.log_out
        @homepage.dev_auth
        @homepage.click_flight_deck_link
        @flight_deck.search_for_topic @topic
        @flight_deck.undelete_topic @topic
      end

      it 'is returned in search results for any notes that include the topic' do
        @student_page.open_adv_search
        @student_page.select_note_topic @topic
        @student_page.click_adv_search_button
        expect(@search_results.note_in_search_result? @note).to be true
      end
    end
  end
end
