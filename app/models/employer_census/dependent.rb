class EmployerCensus::Dependent < EmployerCensus::Member

  EMPLOYEE_RELATIONSHIP_KINDS = %W[spouse child domestic_partner]

  embedded_in :employee_family, class_name: "EmployerCensus::EmployeeFamily"

  validates :employee_relationship,
            presence: true,
            allow_blank: false,
            allow_nil:   false,
            inclusion: { 
              in: EMPLOYEE_RELATIONSHIP_KINDS, 
              message: "'%{value}' is not a valid employee relationship"
            }

  validates :ssn,
    length: { minimum: 8, maximum: 8, message: "SSN must be 8 digits" },
    allow_blank: true,
    numericality: true,
    uniqueness: true

end
