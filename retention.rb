#!/usr/bin/env ruby
# frozen_string_literal: true

require 'time'

def scan_directory(folder)
  Dir.entries(folder).grep_v(/^\.{1,2}$/).sort
end

def get_hostname(filename)
  filename.split('-').first
end

def get_timestamp(filename)
  string = filename.split('-')
  date = "#{string[1]}-#{string[2]}-#{string[3]}"
  time = "#{string[4][0..1]}:#{string[4][2..3]}:#{string[4][4..5]}"
  Time.parse("#{date} #{time}")
end

def last_x_days?(timestamp, days)
  Time.now - timestamp < days * 24 * 60 * 60
end

def get_date(timestamp)
  Time.at(timestamp).to_date
end

def same_day_as_last_backup?(timestamp)
  get_date(timestamp) == get_date(@last_backup_kept)
end

def same_month_as_last_backup?(timestamp)
  Time.at(timestamp).year == Time.at(@last_backup_kept).year &&
    Time.at(timestamp).month == Time.at(@last_backup_kept).month
end

def build_filename_hash(filename)
  {
    filename:,
    hostname: get_hostname(filename),
    timestamp: get_timestamp(filename)
  }
end

def backup_list(folder)
  files = scan_directory(folder)
  backups = []
  files.each do |filename|
    next if filename == '.DS_Store'

    backups << build_filename_hash(filename)
  rescue ArgumentError
    puts "Failed to retrieve timestamp for '#{filename}', ignoring ..."
  end
  backups
end

def host_list(backups)
  backups.map { |fields| fields[:hostname] }.uniq
end

def update_last_backup_kept(timestamp)
  @last_backup_kept = timestamp
end

def build_host_list_and_report(backups, host)
  host_backups = backups.select { |backup| backup[:hostname] == host }
  puts "#{host}: #{host_backups.count}"
  host_backups
end

def first_backup_kept?(timestamp)
  update_last_backup_kept(timestamp) if @last_backup_kept.nil?
end

def find_files_to_delete(backups)
  files_to_delete = []
  host_list(backups).each do |host|
    build_host_list_and_report(backups, host).each do |backup|
      timestamp = backup[:timestamp]
      filename = backup[:filename]

      # Files newer than 7 days should be kept
      next if last_x_days?(timestamp, 7)

      # Files older than 365 days should be deleted
      unless last_x_days?(timestamp, 365)
        files_to_delete << filename
        next
      end

      # Keep if it's the first backup (< 365 days and > 7 days)
      next if first_backup_kept?(timestamp)

      # If older than 90 days, keep the first of the month
      unless last_x_days?(timestamp, 90)
        same_month_as_last_backup?(timestamp) ? files_to_delete << filename : update_last_backup_kept(timestamp)
        next
      end

      # Remaining - newer than 90 days but older than 7 days, keep first of the day
      same_day_as_last_backup?(timestamp) ? files_to_delete << filename : update_last_backup_kept(timestamp)
    end
  end
  files_to_delete
end

# Enter folder to process
folder = 'Machines'

@last_backup_kept = nil
backups = backup_list(folder)
files_to_delete = find_files_to_delete(backups)

backups.each do |backup|
  if files_to_delete.include?(backup[:filename])
    puts "Deleting #{backup[:filename]} ..."
    File.delete("#{folder}/#{backup[:filename]}")
  end
end
