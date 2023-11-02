require "json"
require 'date'
require 'holidays'
require 'business_time'
require 'benchmark'
require 'getoptlong'
# your code

def add_business_time_holiday(date)
  BusinessTime::Config.holidays << date
end

def initialize_business_time(holidays)
  BusinessTime::Config.holidays = holidays.map{|holiday| Date.parse(holiday['day'])}
end

def configurate_business_time(since_date, until_date)
  # BusinessTime needs to get the holydays to esclude them from the calculation of the workings days
  Holidays.cache_between(since_date, until_date, :it, :observed).keys.each{|holiday| add_business_time_holiday(holiday)}
end

def add_birthdays_to_business_time_holiday(since_date, until_date, birthday_date)
  birthday_month = birthday_date.month
  birthday_day = birthday_date.day
  (since_date.year..until_date.year).each do |year|
    add_business_time_holiday(Date.new(year, birthday_month, birthday_day))
  end
end

def read_data_json(input_path)
  File.read(input_path)
rescue Errno::ENOENT, Errno::EACCES => e
  $stderr.puts "While reading the file caught the exception: #{e}"
  raise
end

def write_output_json(output_path, json)
  File.write(output_path, json)
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
  # BusinessTime::Config.holidays we need to remove the dates outside the range
  # Holidays includes the until_date and the weekend days, so we remove them
  business_time_holidays_in_period = BusinessTime::Config.holidays.reject{|holiday| holiday < since_date || holiday > until_date}
  general_holidays = Holidays.between(since_date, until_date, :it).map{|h| h[:date]}
  (business_time_holidays_in_period + general_holidays).uniq.reject{|holiday| holiday.sunday? || holiday.saturday?}.size
end

def calculate_days_available_in_period_for_developers(input_path, output_path)
  data_hash = JSON.parse(read_data_json(input_path))
  periods = data_hash['periods']
  developers = data_hash['developers']
  local_holidays = data_hash['local_holidays']
  
  availabilities = periods.map do |period|
    since_date = Date.parse(period['since'])
    until_date = Date.parse(period['until'])
    next if until_date < since_date
    developers.map do |developer|
      initialize_business_time(local_holidays)
      add_birthdays_to_business_time_holiday(since_date, until_date, Date.parse(developer['birthday']))
      configurate_business_time(since_date, until_date)

      total_days = calculate_total_days(since_date, until_date)
      workdays = calculate_workdays(since_date, until_date)
      holidays = calculate_holidays(since_date, until_date)
      {
        "developer_id": developer['id'],
        "period_id": period['id'],
        "total_days": total_days,
        "workdays": workdays,
        "weekend_days": total_days - (workdays + holidays),
        "holidays": holidays,
      }
    end
  end.flatten
  # same values, different indentation
  write_output_json(output_path, JSON.pretty_generate({"availabilities": availabilities}))
# rescue JSON::ParserError => e
#   $stderr.puts "Caught the JSON exception: #{e}"
#   exit -1
# rescue Date::Error => e
#   $stderr.puts "Caught the Date exception: #{e}"
#   exit -1
# rescue => e
#   $stderr.puts "Caught exception while calculating periods: #{e}"
#   exit -1
end
opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--input', '-i', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--output', '-o', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--time', '-t', GetoptLong::OPTIONAL_ARGUMENT ]
)

input_path = 'data.json'
output_path = 'output.json'
show_time = nil
opts.each do |opt, arg|
    case opt
        when '--help'
            puts <<-EOF
Tractus [OPTION]  
Exclude local holidays, exclude birthdays and calculate how many working days in each period the developer is available.
Loops over the days

-h, --help:
     show help

--input [path], -i [path]:
     the file containing the json with the input data

--output [path], -o [path]:
     the file where to save the resulting json

--time, -t:
     show time

            EOF
        when '--input'
          input_path = arg
        when '--output'
          output_path = arg
        when '--time'
          show_time = true
    end
end

time = Benchmark.measure {
  calculate_days_available_in_period_for_developers(input_path, output_path)
}
puts time.real if show_time
# ruby main.rb  --input 'data.json' -o 'output.json' -t