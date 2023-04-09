require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'time'
require_relative './model.rb'

include Model

enable :sessions
db = SQLite3::Database.new('Daily-Doodle/db/DailyDoodleDatabase.db')
db.results_as_hash = true

helpers do
  # Helper function to access the database
  #
  def getDB()
      db = SQLite3::Database.new('Daily-Doodle/db/DailyDoodleDatabase.db')
      db.results_as_hash = true
      return db
  end

  # Helper function to determine if a user is already following a certain user
  #
  # @param [Integer] followed_user_id, The id of the user being followed
  # @param [Integer] following_user_id, The id of the user following
  def user_is_following(followed_user_id,following_user_id)
      db = getDB()
      return db.execute('SELECT * FROM follows_rel WHERE followed_user_id = ? AND following_user_id = ?',followed_user_id,following_user_id).length != 0
  end

  # Helper function to determine if a user has already like a certain doodle
  #
  # @param [Integer] doodle_id, The id of the liked doodle
  # @param [Integer] user_id, The id of the liking user
  def user_has_liked(doodle_id,user_id)
      db = getDB()
      return db.execute('SELECT * FROM likes_rel WHERE doodle_id = ? AND user_id = ?',doodle_id,user_id).length != 0
  end
end

# Displays landing page, if user is logged in and has already posted today, displays feed
#
# @param [Boolean] session[:loggedin], Stored session if a user is logged in
# @param [String] session[:prompt], Stored session of the current prompt of the day
# @param [Array] doodles, List of hashes of all the doodles posted today
#
# @see Model#user_has_posted
get('/') do
  session[:prompt] = db.execute('SELECT prompt_name FROM prompts WHERE current_prompt = 1').first[0].to_s
  if user_has_posted(session[:id],session[:prompt]) && session[:loggedin] == true
    result = db.execute('SELECT * FROM doodles WHERE prompt = ?',session[:prompt])
    slim(:feed, locals:{doodles:result})
  else
    slim(:start)
  end
end

get('/following') do
  slim(:following)
end

# Updates the current prompt of the day (Note: 1 and 0 are used instead of true and false as booleans aren't inherent in SQLite)
#
# @see Model#update_prompt
post('/prompts/update') do
  update_prompt()
end

# Displays a login form
#
get('/login') do
  slim(:login, locals:{login_message:session[:login_message]})
end

# Attempts login and updates the session(s) 
#
# @param [String] username, The username
# @param [String] password, The password
#
# @param [Integer] session[:id], The id of the user
# @param [String] session[:id], The username of the user
# @param [Boolean] session[:loogedin], Whether or not user is logged in (used for safety in routes)
post('/login') do
  username = params[:username]
  password = params[:password]
  result = db.execute('SELECT * FROM users WHERE username = ?',username).first
  password_digest = result['password_digest']
  id = result['user_id'].to_i
  
  if BCrypt::Password.new(password_digest) == password
    attempts = db.execute('SELECT login_attempts FROM users WHERE username = ?',username).first[0]
    if attempts != nil && attempts >= 4
      lockout_time = Time.parse(db.execute('SELECT lockout_time FROM users WHERE username = ?',username).first[0])
      current_time = Time.now
      elapsed_time = current_time - lockout_time
      if elapsed_time <= 60
        session[:login_message] = "Locked Out For #{(60 - elapsed_time).to_i} Seconds"
        redirect('/login')
      end
    end
    session[:login_message] = ''
    session[:id] = id
    session[:username] = username
    session[:loggedin] = true
    update_login_attempts(username,0)
    redirect('/')
  else
    if user_exists(username)
      attempts = db.execute('SELECT login_attempts FROM users WHERE username = ?',username).first[0] + 1
      update_login_attempts(username,attempts)
      if attempts >= 4
        lockout_time = Time.now.to_s
        update_lockout_time(username,lockout_time)
        session[:login_message] = 'Too Many Recent Failed Login Attempts, Try Again Later'
      else
        session[:login_message] = 'Username-Password Combination Does Not Exist'
      end
    else
      session[:login_message] = 'User Does Not Exist'
    end
    redirect('/login')
  end
end

# Logs out and clears user-specific sessions
#
# @see Model#log_out
post('/logout') do
  log_out()
end

# Displays a form to register a new account
#
get('/users/new') do
  slim(:register)
end

# Displays a user's profile page
# 
# @param [String] :username, The username of the profile's user
get('/users/:username') do
  username = params[:username].to_s
  doodles = db.execute('SELECT * FROM doodles WHERE user_id = (SELECT user_id FROM users WHERE username = ?)',username)
  friends = db.execute('SELECT * FROM follows_rel WHERE following_user_id = (SELECT user_id FROM users WHERE username = ?)',username)
  slim(:profile, locals:{doodles:doodles,friends:friends,username:username})
end

# Attempts to register a new user and adds their data to the database
#
# @param [String] username, The username
# @param [String] password, The password
# @param [String] repeat-password, The repeated password
#
# @see Model#register
post('/users') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  register(username,password,password_confirm)
end

# Displays a form to upload a doodle
#
get('/doodles/new') do
  slim(:upload)
end

# Validates if the inputted file is an image, then saves the image as a file on the local disc and as a URL in the database
# 
# @param [String] image, The image name
# @param [String] path, The image filepath including the image name and extension
post('/doodles') do
  if params[:image] && params[:image][:filename]
    filename = params[:image][:filename]
    file = params[:image][:tempfile]
    dbPath = "/doodles/#{filename}" #/#{session[:prompt]}
    path = "Daily-Doodle/public/doodles/#{filename}"
    db.execute('INSERT into doodles (user_id,url,prompt) VALUES (?,?,?)',session[:id],dbPath,session[:prompt])
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
    redirect('/')
    end
end

# Creates a new follow (many to many relationship) between two users
#
# @param [Integer] followed_user_id, The id of the user being followed
# @param [Integer] user_id, The id of the user following
#
# @see Model#follow
post('/follows') do
  followed_user_id = params[:followed_user_id]
  user_id = session[:id]
  follow(followed_user_id,user_id)
end

# Deletes a follow (many to many relationship)
#
# @param [Integer] followed_user_id, The id of the user being followed
# @param [Integer] user_id, The id of the user following
#
# @see Model#unfollow
post('/follows/delete') do
  followed_user_id = params[:followed_user_id]
  following_user_id = session[:id]
  unfollow(followed_user_id,following_user_id)
end

# Creates a new like (many to many relationship) between a user and a doodle 
#
# @param [Integer] doodle_id, The id of the liked doodle
# @param [Integer] user_id, The id of the liking user
#
# @see Model#like
post('/doodles/:doodle_id/like') do
  doodle_id = params[:doodle_id]
  user_id = session[:id]
  like(doodle_id,user_id)
end

# Deletes like (many to many relationship) 
#
# @param [Integer] doodle_id, The id of the liked doodle
# @param [Integer] user_id, The id of the liking user
#
# @see Model#unlike
post('/doodles/:doodle_id/unlike') do
  doodle_id = params[:doodle_id]
  user_id = session[:id]
  unlike(doodle_id,user_id)
end

# Deletes a doodle
#
# @param [Integer] :doodle_id, The id of the doodle
# @param [Integer] user_id, The id of the user attempting to delete the doodle (used to evaluate the user's eligibility of deleting the doodle)
#
# @see Model#delete_doodle
post('/doodles/:doodle_id/delete') do
  doodle_id = params[:doodle_id].to_i
  user_id = session[:id]
  delete_doodle(doodle_id,user_id)
end

# Reports a doodle
#
# @param [Integer] :doodle_id, The id of the reported doodle
post('/doodles/:doodle_id/report') do
  doodle_id = params[:doodle_id].to_i
  user_id = session[:id]
  if session[:loggedin]
    report(doodle_id,user_id)
  end
end

# Route for debugging countdown timer and current prompt of the day
#
# @param [String] session[:prompt], Current prompt of the day
get('/countdown') do
  session[:prompt] = db.execute('SELECT prompt_name FROM prompts WHERE current_prompt = 1').first[0].to_s
  slim(:prompt)
end