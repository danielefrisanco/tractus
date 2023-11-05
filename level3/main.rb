# ruby main.rb  --input 'data.json' -o 'output.json' -t
require "json"
require 'date'
require 'holidays'
require 'getoptlong'
require 'benchmark'
# your code
class Tractus
  class << self
    def read_data_json(input_path)
      File.read(input_path)
    rescue Errno::ENOENT, Errno::EACCES => e
      raise "While reading the file caught the exception: #{e}"
    end

    def write_output_json(output_path, json)
      File.write(output_path, json)
    rescue Errno::ENOENT, Errno::EACCES => e
      raise "While writing to the file caught the exception: #{e}"
    end

    def extract_limit_dates(data)
      since_date = Date.parse(data['since'])
      until_date = Date.parse(data['until'])
      raise 'period dates are incorrect' if until_date < since_date
      [since_date, until_date]
    end

    def configurate_holidays_for_period(local_holidays, since_date, until_date)
      @holidays = local_holidays.dup
      Holidays.cache_between(since_date, until_date, :it, :observed).keys.each{|holiday| @holidays << holiday}
    end

    def initialize_birthdays(since_date, until_date, birthday_date)
      birthday_month = birthday_date.month
      birthday_day = birthday_date.day
      @birthdays = (since_date.year..until_date.year).map do |year|
        Date.new(year, birthday_month, birthday_day)
      end
    end

    def calculate_total_days(since_date, until_date)
      (until_date - since_date).to_i + 1
    end

    def calculate_workdays(since_date, until_date, number_of_holidays)
      if (until_date.wday + 1) < since_date.wday
        # this case is when the dates are across a weekend and so the rest of the integer division between number of days and 7 would cut the partial week
        # example from friday to wednesday there are 6 days. the number of weekends would be 7/6*2 that results 0 so we add 2
        extra_weekend_days = 2
      elsif since_date.wday == 0 && until_date.wday != 6
        # sunday is wday 0 so we need to correct it
        extra_weekend_days = 1
      elsif since_date.wday != 0 && until_date.wday == 6
        # any week day to sat needs another weekend day
        extra_weekend_days = 1
      else
        extra_weekend_days = 0
      end
      number_of_days = ((until_date - since_date).to_i + 1)
      number_of_days - (number_of_days / 7 * 2) - extra_weekend_days - number_of_holidays
    end


    def calculate_holidays(since_date, until_date)
      # remove the dates outside the range
      # Holidays includes the until_date and the weekend days, so we remove them
      holidays_in_period = @holidays.reject{|holiday| holiday < since_date || holiday > until_date}
      birthdays_in_period = @birthdays.reject{|birthday| birthday < since_date || birthday > until_date}
      general_holidays = Holidays.between(since_date, until_date, :it).map{|h| h[:date]}
      (holidays_in_period + birthdays_in_period + general_holidays).uniq.reject{|holiday| holiday.sunday? || holiday.saturday?}.size
    end


    def calculate_result_days(since_date, until_date)
      total_days = calculate_total_days(since_date, until_date)
      holidays = calculate_holidays(since_date, until_date)
      workdays = calculate_workdays(since_date, until_date, holidays)
      [total_days, holidays, workdays]
    end


    def calculate_projects_feasability(input_path, output_path)
      data_hash = JSON.parse(read_data_json(input_path))
      projects = data_hash['projects']
      raise 'missing projects' if projects.nil?
      developers = data_hash['developers']
      raise 'missing developers' if developers.nil?
      local_holidays_raw = data_hash['local_holidays']
      raise 'missing local_holidays' if local_holidays_raw.nil?
      local_holidays = local_holidays_raw.map{|local_holiday| Date.parse(local_holiday['day'])}

      availabilities = projects.map do |project|
        since_date, until_date = extract_limit_dates(project)
        effort_days = project['effort_days']
        configurate_holidays_for_period(local_holidays, since_date, until_date)
        developers.map do |developer|
          initialize_birthdays(since_date, until_date, Date.parse(developer['birthday']))

          total_days, holidays, workdays = calculate_result_days(since_date, until_date)
          {
            "developer_id": developer['id'],
            "project_id": project['id'],
            "total_days": total_days,
            "workdays": workdays,
            "weekend_days": total_days - (workdays + holidays),
            "holidays": holidays,
            "feasibility": effort_days <= workdays
          }
        end
      end.flatten
      # same values, different indentation
      write_output_json(output_path, JSON.pretty_generate({"availabilities": availabilities}))
    rescue JSON::ParserError => e
      $stderr.puts "Caught the JSON exception: #{e}"
      exit -1
    rescue Date::Error => e
      $stderr.puts "Caught the Date exception: #{e}"
      exit -1
    rescue => e
      $stderr.puts "Caught exception while calculating periods: #{e}"
      exit -1
    end
  end
end





opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--input', '-i', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--output', '-o', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--time', '-t', GetoptLong::OPTIONAL_ARGUMENT ],
)

input_path = 'data.json'
output_path = 'output.json'
show_time = false
run_test = false
opts.each do |opt, arg|
    case opt
        when '--help'
            puts <<-EOF
Tractus [OPTION]  
Very similar to level 2 (faster version) without the business_time gem, just check if there are enough workdays in a period to make the project feasable or not.
This level has also a test
ruby test.rb

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
  Tractus.calculate_projects_feasability(input_path, output_path)
}
puts time.real if show_time

# ruby main.rb  --input 'data.json' -o 'output.json' -t


