require 'sequel'

DB = Sequel.sqlite "db/journal.db"
Sequel.database_timezone = :utc

unless DB.table_exists? :tweets 
  DB.create_table :tweets do
    Time :created_at
    String :text, size: 300
    String :tweet_id, size: 20, unique: true, primary_key: true
  end
end

unless DB.table_exists? :hash_tags
  DB.create_table :hash_tags do
    primary_key :id
    String :text
  end

  DB.create_join_table tweet_id: :tweets, hash_tag_id: :hash_tags
end
