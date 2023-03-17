require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
module Model
    helpers do
        def getDB()
            db = SQLite3::Database.new('db/DailyDoodleDatabase.db')
            db.results_as_hash = true
            return db
        end

        def user_is_following(followed_user_id,following_user_id)
            db = getDB()
            return db.execute('SELECT * FROM follows_rel WHERE followed_user_id = ? AND following_user_id = ?',followed_user_id,following_user_id).length != 0
        end

        def user_has_liked(doodle_id,user_id) #session[:id] som parameter i funktionen
            db = getDB()
            return db.execute('SELECT * FROM likes_rel WHERE doodle_id = ? AND user_id = ?',doodle_id,user_id).length != 0
        end
    end

    def log_out()
        session[:id] = nil
        session[:username] = nil
        session[:loggedin] = false
        redirect('/')
    end

    def register(username,password,password_confirm)
        db = getDB()
        if password == password_confirm
            password_digest = BCrypt::Password.create(password)
            db.execute('INSERT INTO users (username,password_digest) VALUES (?,?)',username,password_digest)
            redirect('/')
        end  
    end

    def user_has_posted(user_id,prompt)
        db = getDB()
        p db.execute('SELECT * FROM doodles WHERE user_id = ? AND prompt = ?',user_id,prompt)
        return db.execute('SELECT * FROM doodles WHERE user_id = ? AND prompt = ?',user_id,prompt).length != 0
    end

    def follow(followed_user_id,user_id)
        db = getDB()
        db.execute('INSERT INTO follows_rel (following_user_id,followed_user_id) VALUES (?,?)',user_id,followed_user_id)
        redirect('/')
    end

    def unfollow(followed_user_id,following_user_id)
        db = getDB()
        db.execute('DELETE FROM follows_rel WHERE following_user_id = ? AND followed_user_id = ?',following_user_id,followed_user_id)
        redirect('/')
    end

    def like(doodle_id,user_id)
        db = getDB()
        db.execute('INSERT INTO likes_rel (user_id,doodle_id) VALUES (?,?)',user_id,doodle_id)
        redirect('/')
    end

    def unlike(doodle_id,user_id)
        db = getDB()
        db.execute('DELETE FROM likes_rel WHERE user_id = ? AND doodle_id = ?',user_id,doodle_id)
        redirect('/')
    end

    def delete_doodle(doodle_id,user_id)
        db = getDB()
        if db.execute('SELECT user_id FROM doodles WHERE doodle_id = ?',doodle_id).first[0] == (user_id || 1) #user_id 1 = admin
            db.execute('DELETE FROM doodles WHERE doodle_id = ?',doodle_id)
        end
        redirect('/')
    end
end