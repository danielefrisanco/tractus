
require "./main"
require "test/unit"
require 'date'

class TestSTestTractusimpleNumber < Test::Unit::TestCase
  def test_calculate_workdays
    start_date = Date.new(2023, 1, 1)
    end_date = Date.new(2023, 1, 1)
    (1..7).each do |day|
      start_date = Date.new(2023, 1, day)
      (0..15).each do |offset|
        weekends = 0
        range = (day..(day+offset))
        weekends += 1 if range.include? 1
        weekends += 1 if range.include? 7
        weekends += 1 if range.include? 8
        weekends += 1 if range.include? 14
        weekends += 1 if range.include? 15
        weekends += 1 if range.include? 21
        weekends += 1 if range.include? 22
        
        holidays = (rand*5).to_i
        end_date = Date.new(2023, 1, day+offset)
        workdays = Tractus.calculate_workdays(start_date, end_date, holidays)
        assert_equal(workdays, offset + 1 - weekends - holidays)
      end
    end
  end

end