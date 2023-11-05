# ruby main.rb  --input 'data.json' -o 'output.json' -t
require "json"
require 'date'
require 'holidays'
require 'getoptlong'
require 'benchmark'

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

    def workday?(date)
      !date.sunday? && !date.saturday? && !@holidays.include?(date)
    end

    def is_birthday?(date)
      @birthdays.include?(date)
    end

    def calculate_developer_distribution_on_projects(input_path, output_path)
      possible_projects_per_day = {}
      min_since_date = nil
      max_until_date = nil
      projects_left_effort_days = {}
      calendar = {}

      data_hash = JSON.parse(read_data_json(input_path))
      
      projects = data_hash['projects']
      raise 'missing projects' if projects.nil?
      developers = data_hash['developers']
      raise 'missing developers' if developers.nil?
      local_holidays_raw = data_hash['local_holidays']
      raise 'missing local_holidays' if local_holidays_raw.nil?
      local_holidays = local_holidays_raw.map{|local_holiday| Date.parse(local_holiday['day'])}
      
      # order by urgency so projects that have more later do not take time earlier from other projects
      projects.sort_by{|project| project['until']}.each do |project|
        since_date, until_date = extract_limit_dates(project)
        configurate_holidays_for_period(local_holidays, since_date, until_date)
        # find min and max project dates
        min_since_date = [min_since_date, since_date].compact.min
        max_until_date = [max_until_date, until_date].compact.max

        # for every project how many effort days are nedeed
        projects_left_effort_days[project['id']] = project['effort_days']
        # every day of the project duration is a possible day to work on it
        (since_date..until_date).each do |current_date|
          if workday?(current_date)
            # exclude already the dates that are not workable, another possibility is to check for workday? together with is_birthday?
            possible_projects_per_day[current_date] ||= []
            possible_projects_per_day[current_date] << project['id']
          end
        end
      end

      # for each developer determine if can work in each date and assign the dev to a project
      developers.each do |developer|
        calendar[developer['id']] ||= {}
        # initialize the birthdays in the period for the dev
        initialize_birthdays(min_since_date, max_until_date, Date.parse(developer['birthday']))
          possible_projects_per_day.each do |current_date, possible_projects|
          if !is_birthday?(current_date)
          # for each project in this day that is not completed assign the dev
            possible_projects.each do |project_id|
              if projects_left_effort_days[project_id] > 0
                # decrease how many effort days are needed to complete the project and assign the developer
                projects_left_effort_days[project_id] -= 1
                calendar[developer['id']][project_id] ||= []
                calendar[developer['id']][project_id] << current_date.to_s
                break
              end
            end
          end
        end
      end

      # sort and prepare the resulting hash
      result = calendar.map do |dev_id, project_days|
        project_days.sort.map do |proj_id, days|
          {
            'developer_id': dev_id,
            'project_id': proj_id,
            'tot_working_days': days.length,
            'working_days': days
          }
        end
      end.flatten

      write_output_json(output_path, JSON.pretty_generate(result))
      
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
    [ '--time', '-t', GetoptLong::OPTIONAL_ARGUMENT ]
)

input_path = 'data.json'
output_path = 'output.json'
show_time = false
opts.each do |opt, arg|
    case opt
        when '--help'
            puts <<-EOF
Tractus [OPTION]
This is more complicated and does not need the calculation of the workdays.
For every project we fill a period and order the projects by ending date, so they have priority.
For every dev and every day in the project period we allocate to that project the dev if it is available, and decrease the effort necessary.
does not take into account the feasability because in the redme there is no word about it.
If feasability needs to be taken into account it is possible to take some code from level3 and integrate it.

In this case it is not possible to use simple math operations because each project consumes the days that would also be available for the other projocts,
so needs to loop over each day, also to have the list of the days.
The alternative (in another file) (that returns only the tot_working_days and not the specific dates) is more complex and the idea is to calculate every sub period where one or more project is taking place, calculate the working days for every dev in that subperiod and allocate them until the effort is 0, the remaing days should be assigned to another project in that same subperiod.


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
  Tractus.calculate_developer_distribution_on_projects(input_path, output_path)
}
puts time.real if show_time

















# ruby main.rb  --input 'data.json' -o 'output.json' -t
