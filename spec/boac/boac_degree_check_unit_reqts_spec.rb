describe 'A BOA degree check' do

  describe 'unassigned course' do
    it 'can have unit requirements added with no affect on totals'
    it 'can have unit requirements edited with no affect on totals'
    it 'can have unit requirements removed with no affect on totals'
  end

  describe 'course' do
    before(:all) do
      # TEST DATA:
      # Completed course #1 - define unit fulfillment
      # Category - define unit fulfillment
      # 	Subcategory	- define no unit fulfillment (inherit from parent)
      # 	Course Requirement - define no unit fulfillment (inherit from parent)
    end
    context 'with unit fulfillment defined' do
      context 'that is assigned to a category' do
        it 'shows its unit fulfillment rather than the category\'s'
        it 'shows an indicator that its unit fulfillment differs from the category\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is reassigned to a subcategory' do
        it 'reverts the category\'s unit fulfillment'
        it 'shows its unit fulfillment rather than the subcategory\'s'
        it 'shows an indicator that its unit fulfillment differs from the subcategory\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is unassigned from a subcategory' do
        it 'reverts the subcategory\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
      context 'that is assigned to a course requirement' do
        it 'shows its unit fulfillment rather than the course requirement\'s'
        it 'shows an indicator that its unit fulfillment differs from the course requirement\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is unassigned from a course requirement' do
        it 'reverts the course requirement\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
    end

    context 'without unit fulfillment defined' do
      before(:all) do
        # TEST DATA:
        # Completed course #2 - define no unit fulfillment
        # Category - define no unit fulfillment
        # 	Subcategory	- define unit fulfillment (override parent)
        # 		Course Requirement (PHANTOM)
      end
      context 'that is assigned to a category' do
        it 'shows the category\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the category\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is unassigned from a category' do
        it 'reverts the category\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
      context 'that is assigned to a subcategory' do
        it 'shows the subcategory\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the subcategory\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is reassigned to a course requirement' do
        it 'reverts the subcategory\'s unit fulfillment'
        it 'updates the unit fulfillment totals'
        it 'shows the course requirements\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the course requirement\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is unassigned from a course requirement' do
        it 'reverts the course requirement\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
    end
  end

  describe 'course copy' do
    before(:all) do
      # TEST DATA:
      # Completed course #3 (define unit fulfillment, assign, COPY)
      # Category - define no unit fulfillment
      # 	Subcategory	- define no unit fulfillment (inherit from parent)
      # 	  Course Requirement (PHANTOM)
    end
    context 'with unit fulfillment defined' do
      context 'that is assigned to a category' do
        it 'shows its unit fulfillment rather than the category\'s'
        it 'shows an indicator that its unit fulfillment differs from the category\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is unassigned from a category' do
        it 'reverts the category\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
      context 'that is assigned to a subcategory' do
        it 'shows its unit fulfillment rather than the subcategory\'s'
        it 'shows an indicator that its unit fulfillment differs from the subcategory\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is reassigned to a course requirement' do
        it 'reverts the subcategory\'s unit fulfillment'
        it 'updates the unit fulfillment totals'
        it 'shows its unit fulfillment rather than the course requirement\'s'
        it 'shows an indicator that its unit fulfillment(s) differ from the course requirement\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'can have unit fulfillment added and totals updated'
        it 'can have unit fulfillment removed and totals updated'
      end
      context 'that is unassigned from a course requirement' do
        it 'reverts the course requirement\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
    end

    context 'without unit fulfillment defined' do
      before(:all) do
        # TEST DATA:
        # Completed course #4 (define no unit fulfillment, assign, COPY)
        # Category - define no unit fulfillment
        # 	Subcategory	- define unit fulfillment (override parent)
        #	  Course Requirement - define unit fulfillment (override parent)
      end
      context 'that is assigned to a category' do
        it 'shows the category\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the category\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is reassigned to a subcategory' do
        it 'reverts the category\'s unit fulfillment'
        it 'updates the unit fulfillment totals'
        it 'shows the subcategory\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the subcategory\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is unassigned from a subcategory' do
        it 'reverts the subcategory\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
      context 'that is assigned to a course requirement' do
        it 'shows the course requirements\'s unit fulfillment rather than its own'
        it 'shows no indicator that its unit fulfillment differs from the coures requirement\'s'
        it 'updates the unit fulfillment totals'
        it 'can have unit fulfillment edited and totals updated'
        it 'shows an indicator if its unit fulfillment has been edited'
        it 'can have unit fulfillment added and totals updated'
        it 'shows an indicator if its unit fulfillment has been added'
        it 'can have unit fulfillment removed and totals updated'
        it 'shows an indicator if its unit fulfillment has been removed'
      end
      context 'that is unassigned from a course requirement' do
        it 'reverts the course requirement\'s unit fulfillment'
        it 'retains its own unit fulfillment'
        it 'updates the unit fulfillment totals'
      end
    end
  end
end
