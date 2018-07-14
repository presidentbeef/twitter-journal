require 'sinatra'
require_relative '../lib/journal'

J = Journal.new(DB, {})

get '/' do
  erb :index, locals: { tweets: J.tweets_by_day }
end
