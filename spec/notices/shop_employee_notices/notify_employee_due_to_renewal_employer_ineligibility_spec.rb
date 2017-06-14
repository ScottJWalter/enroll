require 'rails_helper'

RSpec.describe ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility, :dbclean => :after_each do
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month.next_month.prev_year}
  let!(:employer_profile){ create :employer_profile, aasm_state: "active"}
  let!(:person){ create :person}
  let!(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on,:aasm_state => 'active' ) }
  let!(:active_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }
  let!(:renewal_plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on + 1.year, :aasm_state => 'renewing_publish_pending' ) }
  let!(:renewal_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: renewal_plan_year, title: "Benefits #{renewal_plan_year.start_on.year}") }
  let(:employee_role) {FactoryGirl.create(:employee_role, person: person, employer_profile: employer_profile)}
  let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id, employer_profile_id: employer_profile.id) }
  let(:application_event){ double("ApplicationEventKind",{
                            :name =>'Notify Employees of their employer termination due to ineligibility',
                            :notice_template => 'notices/shop_employee_notices/notification_to_employee_due_to_initial_employer_ineligibility',
                            :notice_builder => 'ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility',
                            :event_name => 'notify_employee_of_renewing_employer_ineligibility',
                            :mpi_indicator => 'MPI_SHOP10066',
                            :title => "Termination of Employer’s Health Coverage Offered through DC Health Link"})
                          }

    let(:valid_parmas) {{
        :subject => application_event.title,
        :mpi_indicator => application_event.mpi_indicator,
        :event_name => application_event.event_name,
        :template => application_event.notice_template
    }}

  describe "New" do
    before do
      @employee_notice = ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility.new(census_employee, valid_parmas)
    end
    context "valid params" do
      it "should initialze" do
        expect{ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility.new(census_employee, valid_parmas)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_parmas.delete(key)
          expect{ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility.new(census_employee, valid_parmas)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    before do
      @employee_notice = ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility.new(census_employee, valid_parmas)
    end
    it "should build notice with all necessory info" do

      @employee_notice.build
      expect(@employee_notice.notice.primary_fullname).to eq person.full_name.titleize
      expect(@employee_notice.notice.employer_name).to eq employer_profile.organization.legal_name
    end
  end

  describe "append data" do
    before do
      @employee_notice = ShopEmployeeNotices::NotifyEmployeeDueToRenewalEmployerIneligibility.new(census_employee, valid_parmas)
    end
    it "should append data" do
      @employee_notice.append_data
      expect(@employee_notice.notice.plan_year.end_on).to eq plan_year.end_on
    end
  end

end