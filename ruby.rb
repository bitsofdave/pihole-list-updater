#!/usr/local/bin/ruby

require 'net/http'
require "sqlite3"



firebog_list_tick = URI('https://v.firebog.net/hosts/lists.php?type=tick')
firebog_list_nocross = URI('https://v.firebog.net/hosts/lists.php?type=nocross')

res = Net::HTTP.get_response(firebog_list_tick)

if res.code == '200'
  # p res.body
  lines = res.body.split("\n")
  lines.each do |line|
    p line
  end
# if res.code == '200'
else
  p "http request failed with #{res.code}"
end


begin
	db = SQLite3::Database.new "/etc/pihole/gravity_test.db"

  columns = db.execute("pragma table_info(adlist)")
  p columns.map { |c| c[1] }.join(', ')

#	db.execute("select * from domainlist") do |row|
#		p row
#	end
  query = "SELECT * FROM adlist"

  db.execute(query) do |row|
    p row
  end

rescue SQLite3::Exception => e
  p "Exception:"
  p e
ensure
	db.close if db
end

