require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
module Model
    def get_DB()
        db = SQLite3::Database.new('Daily-Doodle/db/DailyDoodleDatabase.db')
        db.results_as_hash = true
        return db
    end
    # Updates the current prompt of the day by changing the 'current_prompt' column
    #
    def update_prompt()
        db = get_DB()
        current_prompt_id = db.execute('SELECT prompt_id FROM prompts WHERE current_prompt = 1').first[0]
        new_prompt_id = db.execute('SELECT prompt_id FROM prompts ORDER BY RANDOM() LIMIT 1').first[0]
        db.execute('UPDATE prompts SET current_prompt = 0 WHERE prompt_id = ?',current_prompt_id)
        db.execute('UPDATE prompts SET current_prompt = 1 WHERE prompt_id = ?',new_prompt_id)
        redirect('/')
    end

    # Checks if a user exists with a certain username
    #
    def user_exists(username)
        db = get_DB()
        return db.execute('SELECT user_id FROM users WHERE username = ?',username) != nil
    end

    # Updates the amount of login attempts a user has made
    #
    def update_login_attempts(username,attempts)
        db = get_DB()
        db.execute('UPDATE users SET login_attempts = ? WHERE username = ?',attempts,username)
    end

    # Updates the time a user has been locked out of logging in
    #
    def update_lockout_time(username,time)
        db = get_DB()
        db.execute('UPDATE users SET lockout_time = ? WHERE username = ?',time,username)
    end

    # Clears all user-related sessions
    #
    # @params [Integer] session[:id], The stored id of the current user
    # @params [String] session[:username], The stored username of the current user
    # @params [Boolean] session[:loggedin], Global bool used to determine if someone is logged in
    def log_out()
        session[:id] = nil
        session[:username] = nil
        session[:loggedin] = false
        redirect('/')
    end

    # Creates a new user in the 'users' table
    #
    # @param [String] username, The username
    # @param [String] password, The password (Password is stored as password digest in database)
    # @param [String] password-confirm, Repeated password for confirmation (Password is stored as password digest in database)
    def register(username,password,password_confirm)
        db = get_DB()
        if password == password_confirm
            password_digest = BCrypt::Password.create(password)
            db.execute('INSERT INTO users (username,password_digest) VALUES (?,?)',username,password_digest)
            redirect('/login')
        end  
    end

    # Determines if a certain user has posted a doodle with today's prompt
    #
    # @param [Integer] user_id, The id of the user
    # @param [String] prompt, The current prompt of the day
    def user_has_posted(user_id,prompt)
        db = get_DB()
        p db.execute('SELECT * FROM doodles WHERE user_id = ? AND prompt = ?',user_id,prompt)
        return db.execute('SELECT * FROM doodles WHERE user_id = ? AND prompt = ?',user_id,prompt).length != 0
    end

    # Creates a follow (many to many relationship) between two users
    #
    # @param [Integer] followed_user_id, The id of the user being followed
    # @param [Integer] user_id, The id of the user following
    def follow(followed_user_id,user_id)
        db = get_DB()
        db.execute('INSERT INTO follows_rel (following_user_id,followed_user_id) VALUES (?,?)',user_id,followed_user_id)
        redirect('/')
    end

    # Deletes a follow (many to many relationship) between two users
    #
    # @param [Integer] followed_user_id, The id of the user being followed
    # @param [Integer] user_id, The id of the user following
    def unfollow(followed_user_id,following_user_id)
        db = get_DB()
        db.execute('DELETE FROM follows_rel WHERE following_user_id = ? AND followed_user_id = ?',following_user_id,followed_user_id)
        redirect('/')
    end

    # Creates a report (many to many relationship) between a user and a doodle
    #
    # @param [Integer] doodle_id, The id of the reported doodle
    # @param [Integer] user_id, The id of the reporting user
    def report(doodle_id,user_id)
        db = get_DB()
        db.execute('INSERT INTO reports_rel (user_id,doodle_id) VALUES (?,?)',user_id,doodle_id)
        if db.execute('SELECT COUNT(report_id) FROM reports_rel WHERE doodle_id = ?',doodle_id).first[0] >= 3
            delete_doodle(doodle_id,1)
        end
        redirect('/')
    end

    # Creates a like (many to many relationship) between a user and a doodle
    #
    # @param [Integer] doodle_id, The id of the liked doodle
    # @param [Integer] user_id, The id of the liking user
    def like(doodle_id,user_id)
        db = get_DB()
        db.execute('INSERT INTO likes_rel (user_id,doodle_id) VALUES (?,?)',user_id,doodle_id)
        redirect('/')
    end
   
    # Deletes a like (many to many relationship) between a user and a doodle
    #
    # @param [Integer] doodle_id, The id of the liked doodle
    # @param [Integer] user_id, The id of the liking user
    def unlike(doodle_id,user_id)
        db = get_DB()
        db.execute('DELETE FROM likes_rel WHERE user_id = ? AND doodle_id = ?',user_id,doodle_id)
        redirect('/')
    end

    # Checks if the user is eligible for deleting a certain post and then deletes it (ON-DELETE CASCADE)
    #
    # @param [Integer] doodle_id, The id of the doodle being deleted
    # @param [Integer] user_id, The id of the user attempting to delete the doodle
    def delete_doodle(doodle_id,user_id)
        db = get_DB()
        if user_id == db.execute('SELECT user_id FROM doodles WHERE doodle_id = ?',doodle_id).first[0] || user_id == 1 #user_id 1 = admin
            db.execute('DELETE FROM doodles WHERE doodle_id = ?',doodle_id)
            db.execute('DELETE FROM likes_rel WHERE doodle_id = ?',doodle_id) #CASCADE
            db.execute('DELETE FROM reports_rel WHERE doodle_id = ?',doodle_id) #CASCADE
        end
        redirect('/')
    end
end