  require 'csv'
  
  batch_size = 500
  offset = 0

  org_count = Organization.count
  field_names  = %w(
             Group_name
             FEIN
             Broker_Name
             Broker_NPN
             Broker_Assignment_Start
             Broker_Assignment_end
             )

  file_name = "#{Rails.root}/brokers_assignment_report_#{TimeKeeper.date_of_record.strftime("%m_%d_%Y")}.csv"

  CSV.open(file_name, "w", force_quotes: true) do |csv|
    
    csv << field_names

    while offset < org_count
      Organization.offset(offset).limit(batch_size).where("employer_profile" => {"$exists" => true}).map(&:employer_profile).each do |employer|
        employer.broker_agency_accounts.unscoped.all.each do |ba_account|
          next if  (ba_account.nil? || ba_account.broker_agency_profile.nil?) || ba_account.created_at >= Date.new(2016,1,1) ||  ba_account.broker_agency_profile.market_kind == "individual"
          csv << [
            employer.legal_name,
            ba_account.broker_agency_profile.fein,
            ba_account.broker_agency_profile.primary_broker_role.person.full_name,
            ba_account.broker_agency_profile.primary_broker_role.npn,
            ba_account.start_on,
            ba_account.end_on
          ]
        end
      end
      offset = offset + batch_size
    end
    puts "For period #{date_range.first} - #{date_range.last}, #{processed_count} Brokers to output file: #{file_name}" unless Rails.env.test?
  end