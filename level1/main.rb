require "json"
require 'date'
require 'holidays'
require 'business_time'
# your code
# I use holiday gem to have a list of italian holidays, 
# business_time just loops over the days, but it is easy to use so 

def configurate_business_time(since_date, until_date)
  # BusinessTime needs to get the holydays to esclude them from the calculation of the workings days
  Holidays.cache_between(since_date, until_date, :it, :observed)
  Holidays.between(since_date, until_date, :it, :observed).each{|holiday| BusinessTime::Config.holidays << holiday[:date]}
end

def read_data_json
  File.read('data.json')
rescue Errno::ENOENT, Errno::EACCES => e
  $stderr.puts "While reading the file caught the exception: #{e}"
  raise
end

def write_output_json(json)
  File.write('output.json', json)
rescue Errno::ENOENT, Errno::EACCES => e
  $stderr.puts "While writing to the file caught the exception: #{e}"
  raise
end

def calculate_total_days(since_date, until_date)
  (until_date - since_date).to_i + 1
end

def calculate_workdays(since_date, until_date)
  # business_days_until excludes the last day
  since_date.business_days_until(until_date + 1.day)
end

def calculate_holidays(since_date, until_date)
  # Holidays includes the until_date and the weekend days, so we remove them
  Holidays.between(since_date, until_date, :it).reject{|holiday| holiday[:date].sunday? || holiday[:date].saturday?}.size
end

def calculate_days_available_in_period
  data_hash = JSON.parse(read_data_json)
  availabilities = data_hash['periods'].map do |period|
    since_date = Date.parse period['since']
    until_date = Date.parse period['until']
    next if until_date < since_date
    configurate_business_time(since_date, until_date)

    total_days = calculate_total_days(since_date, until_date)
    workdays = calculate_workdays(since_date, until_date)
    holidays = calculate_holidays(since_date, until_date)
    {
      "period_id": period['id'],
      "total_days": total_days,
      "workdays": workdays,
      "weekend_days": total_days - (workdays + holidays),
      "holidays": holidays,
    }
  end
  # same values, different indentation
  write_output_json(JSON.pretty_generate({"availabilities": availabilities}))
rescue JSON::ParserError => e
  $stderr.puts "Caught the JSON exception: #{e}"
  exit -1
rescue => e
  $stderr.puts "Caught exception while calculating periods: #{e.inspect}"
  exit -1
end
calculate_days_available_in_period