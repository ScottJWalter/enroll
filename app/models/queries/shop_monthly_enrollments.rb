module Queries
  class ShopMonthlyEnrollments
    include QueryHelpers

    def initialize(feins, effective_on)
      @feins = feins
      @effective_on = effective_on
      @pipeline = []
    end

    def add(step)
      @pipeline << step.to_hash
    end

    def evaluate
      Family.collection.aggregate(@pipeline)
    end

    def query_families
      add({
        "$match" => {
          "households.hbx_enrollments.benefit_group_id" => {
            "$in" => (collect_benefit_group_ids + collect_benefit_group_ids(@effective_on.prev_year))
          }
        }
      })

      self
    end

    def unwind_enrollments
      add({"$unwind" => "$households"})
      add({"$unwind" => "$households.hbx_enrollments"})
      self
    end

    def unwind_enrollment_members
     add({"$unwind" => "$households.hbx_enrollments.hbx_enrollment_members"})
     self
    end

    def new_enrollment_statuses
      HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES + HbxEnrollment::TERMINATED_STATUSES
    end

    def existing_enrollment_statuses
      HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES + ['coverage_expired']
    end

    def new_coverage_expression
      {
        "households.hbx_enrollments.benefit_group_id" => {"$in" => collect_benefit_group_ids},
        "households.hbx_enrollments.aasm_state" => {"$in" => new_enrollment_statuses},
        "households.hbx_enrollments.effective_on" => @effective_on,
        "households.hbx_enrollments.enrollment_kind" => "open_enrollment"
      }
    end

    def existing_coverage_expression
      {
        "households.hbx_enrollments.benefit_group_id" => {"$in" => collect_benefit_group_ids(@effective_on.prev_year)},
        "households.hbx_enrollments.aasm_state" => {"$in" => existing_enrollment_statuses},
        "households.hbx_enrollments.effective_on" => {"$gte" => @effective_on.prev_year}
      }
    end

    def query_enrollments
      add({
        "$match" => {
          "$or" => [
            new_coverage_expression, 
            existing_coverage_expression
          ]
        }
      })

      self
    end

    def project_enrollments_with_subscriber
     add({
      "$project" => {"households.hbx_enrollments" => 1, "family_member" => {"$cond" => [{"$eq" => ["$households.hbx_enrollments.hbx_enrollment_members.is_subscriber", true]}, "$households.hbx_enrollments.hbx_enrollment_members.applicant_id", nil]}}
     })

     self
    end

    def filter_missing_subscribers
      add({
        "$match" => {"family_member" => {"$ne" => nil}}
      })

      self
    end

    def group_enrollments
      add({
        "$group" => {
          "_id" => {
            "subscriber" => "$family_member",
            "effective_on" => "$households.hbx_enrollments.effective_on",
            "employee_role_id" => "$households.hbx_enrollments.employee_role_id",
            "bga_id" => "$households.hbx_enrollments.benefit_group_assignment_id",
            "coverage_kind" => "$households.hbx_enrollments.coverage_kind"
          },
          "hbx_enrollment_id" => {"$last" => "$households.hbx_enrollments.hbx_id"}
        }
      })

      self
    end

    def sort(attribute = nil)
      add({
       "$sort" => {"households.hbx_enrollments.#{attribute}" => 1}
       })

      self
    end

    def project_enrollment_ids
      add({
        "$project" => {
         "_id" => 1,
         "enrollment_hbx_id" => "$hbx_enrollment_id"
        }
      })

      self
    end

    def collect_benefit_group_ids(effective_on = nil)
      @feins.collect{|e| prepend_zeros(e.to_s, 9) }.inject([]) do |id_list, fein|
        employer = EmployerProfile.find_by_fein(fein)
        if employer.present?
          plan_years = employer.plan_years.where(:aasm_state.in => PlanYear::PUBLISHED + PlanYear::RENEWING_PUBLISHED_STATE + ['expired'])
          plan_year = plan_years.where(:start_on => effective_on || @effective_on).first
        end      

        if plan_year.present?
          id_list += plan_year.benefit_groups.map(&:id)
        else
          id_list
        end
      end
    end

    def prepend_zeros(number, n)
      (n - number.to_s.size).times { number.prepend('0') }
      number
    end
  end
end