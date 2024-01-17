#!/usr/local/bin/ruby

require 'net/http'
require "sqlite3"

adlists = {
  :firebog_list_tick => URI('https://v.firebog.net/hosts/lists.php?type=tick'),
  :firebog_list_nocross => URI('https://v.firebog.net/hosts/lists.php?type=nocross'),
}

regex_blacklists = {
  :mmotti_regex_list => URI('https://raw.githubusercontent.com/mmotti/pihole-regex/master/regex.list'),
}

exact_whitelists = {
  :anudeepND_whitelist => URI('https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt'),
  :anudeepND_referral_sites => URI('https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/referral-sites.txt'),
  # :anudeepND_optional_list => URI('https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/optional-list.txt'),

  :mmotti_whitelist => URI('https://raw.githubusercontent.com/mmotti/pihole-regex/master/whitelist.list'),
}

# domainlist types
# https://docs.pi-hole.net/database/gravity/#domain-tables-domainlist
EXACT_WHITELIST = 0
EXACT_BLACKLIST = 1
REGEX_WHITELIST = 2
REGEX_BLACKLIST = 3


PIHOLE_LIST_UPDATER_COMMENT = 'Managed by pihole-list-updater'.freeze

DEFAULT_LISTS = [
  'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts',
  'https://mirror1.malwaredomains.com/files/justdomains',
]

#EXACT_WHITELIST
my_list = [
  'insights.newrelic.com',
  'kinesis.us-east-1.amazonaws.com',
  'p.typekit.net',
  'one.newrelic.com',
  'frame-infrastructure.newrelic.com',
  'frame-alerts.newrelic.com',
  'discuss.newrelic.com',
  'download.newrelic.com',
]

def http_get(uri)
  res = Net::HTTP.get_response(uri)
  if res.code == '200'
    lines = res.body.split("\n")
    lines.reject { |line| line.start_with?('#') || line.empty? }.uniq
  else
    puts "http request failed with #{res.code}"
  end
end


def sync_list(table_name, column_name, lines, domain_type=nil)
  # adlist
  # "id, address, enabled, date_added, date_modified, comment"
  # UNIQUE(address)

  # domainlist
  # "id, type, domain, enabled, date_added, date_modified, comment"
  # UNIQUE(domain, type)

  begin
    db = SQLite3::Database.new "/etc/pihole/gravity.db"
    db.results_as_hash = true

    columns = db.execute("pragma table_info(#{table_name})")
    puts columns.map { |c| c[1] }.join(', ')

    source_items = lines.map { |line| "#{line}" }

    questions = source_items.map { '?' }
    sql = """
      SELECT *
      FROM #{table_name}
      WHERE comment = '#{PIHOLE_LIST_UPDATER_COMMENT}'
    """.strip
    sql += " AND type=#{domain_type}" if table_name === 'domainlist'

    stmt = db.prepare(sql)
    # WHERE address IN (#{questions.join(',')})

    #stmt.bind_params(*source_items)
    result = stmt.execute

    # for row in result
    #   p row["address"]
    # end

    database_items = result.map { |row| row[column_name] }

    # items from source that are not in the database
    new_items = source_items.reject { |line| database_items.include? line }
    new_items = new_items.reject { |line| DEFAULT_LISTS.include? line }

    # items from database that are not in the source
    removed_items = database_items.reject { |line| source_items.include? line }
    removed_items = removed_items.reject { |line| DEFAULT_LISTS.include? line }

    unless new_items.empty?
      puts "new_items"
      p new_items

      if table_name === 'adlist'
        columns = [column_name, 'enabled', 'comment']
      else
        columns = [column_name, 'enabled', 'comment', 'type']
      end

      new_items_sql = new_items.map do |item|
        if table_name === 'adlist'
          "('#{item}', 1, '#{PIHOLE_LIST_UPDATER_COMMENT}')"
        else
          "('#{item}', 1, '#{PIHOLE_LIST_UPDATER_COMMENT}', #{domain_type})"
        end
      end

      insert_sql = """
        INSERT INTO #{table_name} (#{columns.join(', ')})
        VALUES #{new_items_sql.join(',')}
      """.strip

      puts insert_sql
      db.execute(insert_sql)
      num_affected = db.changes

      puts "Inserted #{num_affected}/#{new_items.length} items"
    end

    unless removed_items.empty?
      puts "removed_items"
      p removed_items

      delete_sql = """
        DELETE FROM #{table_name}
        WHERE #{column_name} IN ('#{removed_items.join("','")}')
      """.strip

      delete_sql += " AND type=#{domain_type}" if table_name === 'domainlist'

      puts delete_sql
      db.execute(delete_sql)
      num_affected = db.changes
      # p db.errmsg
      # p db.errcode

      puts "Deleted #{num_affected}/#{removed_items.length} items"
    end

    stmt.close

  rescue SQLite3::Exception => e
    puts "Exception:"
    p e
  ensure
    db.close if db
  end

  puts "\n"
end

# lines = my_list
# sync_list(type=EXACT_WHITELIST, 'domainlist', 'domain', lines)

puts '--- adlist ---'
lines = adlists.map { |key, list| http_get(list) }.flatten.uniq
sync_list(table_name='adlist', column_name='address', lines=lines, domain_type=nil)

puts '--- domainlist (REGEX_BLACKLIST) ---'
lines = regex_blacklists.map { |key, list| http_get(list) }.flatten.uniq
sync_list(table_name='domainlist', column_name='domain', lines=lines, domain_type=REGEX_BLACKLIST)

puts '--- domainlist (EXACT_WHITELIST) ---'
lines = exact_whitelists.map { |key, list| http_get(list) }.flatten.uniq
sync_list(table_name='domainlist', column_name='domain', lines=lines, domain_type=EXACT_WHITELIST)
