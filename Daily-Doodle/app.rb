require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

include Model

enable :sessions
db = SQLite3::Database.new('db/DailyDoodleDatabase.db')
db.results_as_hash = true

get('/') do
  session[:prompt] = db.execute('SELECT prompt_name FROM prompts WHERE current_prompt = 1').first[0].to_s
  if user_has_posted(session[:id],session[:prompt]) && session[:loggedin] == true
    result = db.execute('SELECT * FROM doodles WHERE prompt = ?',session[:prompt])
    slim(:feed, locals:{doodles:result})
  else
    slim(:start)
  end
end

#Eftersom det inte finns bools i SQLite använder jag integersen (1,0) som (true,false)
post('/prompts/update') do
  #update_current_prompt()
  current_prompt_id = db.execute('SELECT prompt_id FROM prompts WHERE current_prompt = 1').first[0]
  new_prompt_id = db.execute('SELECT prompt_id FROM prompts ORDER BY RANDOM() LIMIT 1').first[0]
  db.execute('UPDATE prompts SET current_prompt = 0 WHERE prompt_id = ?',current_prompt_id)
  db.execute('UPDATE prompts SET current_prompt = 1 WHERE prompt_id = ?',new_prompt_id)
  redirect('/')
end

get('/showlogin') do
  slim(:login)
end

post('/login') do
  username = params[:username]
  password = params[:password]
  result = db.execute('SELECT * FROM users WHERE username = ?', username).first
  password_digest = result['password_digest']
  id = result['user_id'].to_i
  
  if BCrypt::Password.new(password_digest) == password
    session[:id] = id
    session[:username] = username
    session[:loggedin] = true
    redirect('/')
  else
    "Username-Password Combination Does Not Exist"
  end
end

post('/logout') do
  log_out()
end

get('/users/new') do
  slim(:register)
end

get('/users/:username') do
  slim(:profile)
end

post('/users') do #ta bort new
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  register(username,password,password_confirm)
end

get('/doodles/new') do
  slim(:upload)
end

post('/doodles') do
  # Kolla ifall det är en bild usern har uploadat
  if params[:image] && params[:image][:filename]
    filename = params[:image][:filename]
    file = params[:image][:tempfile]
    dbPath = "/doodles/#{filename}" #/#{session[:prompt]}
    path = "./public/doodles/#{filename}"
    db.execute('INSERT into doodles (user_id,url,prompt) VALUES (?,?,?)',session[:id],dbPath,session[:prompt])
    # Spara filen på lokal
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
    redirect('/')
    end
end

post('/follows') do
  followed_user_id = params[:followed_user_id]
  user_id = session[:id]
  follow(followed_user_id,user_id)
end

post('/follows/delete') do
  followed_user_id = params[:followed_user_id]
  following_user_id = session[:id]
  unfollow(followed_user_id,following_user_id)
end

post('/doodles/:doodle_id/like') do
  doodle_id = params[:doodle_id]
  user_id = session[:id]
  like(doodle_id,user_id)
end

post('/doodles/:doodle_id/unlike') do
  doodle_id = params[:doodle_id]
  user_id = session[:id]
  unlike(doodle_id,user_id)
end

post('/doodles/:doodle_id/delete') do
  doodle_id = params[:doodle_id].to_i
  user_id = session[:id]
  delete_doodle(doodle_id,user_id)
end

post('/doodles/:doodle_id/report') do
  doodle_id = params[:doodle_id]

  redirect('/')
end

get('/feed') do
  slim(:feed)
end

get('/countdown') do
  session[:prompt] = db.execute('SELECT prompt_name FROM prompts WHERE current_prompt = 1').first[0].to_s
  slim(:prompt)
end



#kunna ta bort allt en användare har (typ id vid flera tabeller)
#On-delete cascade
#Säkra upp routes
#Validering
#REST/model