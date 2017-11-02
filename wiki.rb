=begin
We used the sinatra design framework over others such as rails
We also used datamapper as our database to hold all users
PP was used for error testing
=end
require 'sinatra'
require 'data_mapper'
require 'pp'
set :logging, :true
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/wiki.db")
class User
    include DataMapper::Resource
    property :id, Serial
    property :username, Text, :required => true
    property :password, Text, :required => true
    property :date_joined, DateTime
    property :edit, Boolean, :required => true, :default => false
end
DataMapper.finalize.auto_upgrade!
#Defined helper methods to check user credentials for certain pages
helpers do 
    def protected!
        if authorized?
            return
        end
        redirect '/denied'
    end
    
    def authorized?
        if $credentials != nil
            @Userz = User.first(:username => $credentials[0])
            if @Userz
                if @Userz.edit == true
                    return true
                else 
                    return false
                end
            else
                return false
            end
        end
    end
end
$credentials = [' ',' ']
$currentFile = "wiki.txt"
#Home page
#Pass in parameters that get the post from the current file chosen along with the wiki subheading
#Count the words and chars
#Done by Amit
get '/' do
    file = File.open($currentFile, "r")
    @info = file.read
    file.close
    f = File.open("wikiSubHeading.txt", "r")
    @infoheader = f.read
    f.close
    @words = @info.split.size + @infoheader.split.size
    @chars = @info.size + @infoheader.size
    erb :home
end

get '/about' do
    erb :about
end

get '/create' do
    erb :create
end

get '/edit' do
    info = ""
    file = File.open($currentFile)
    file.each do |line|
        info = info + line
    end
    file.close
    f = File.open("wikiSubHeading.txt")
    @infoheader = f.read
    f.close
    @info = info
    erb :edit
end

#Replace the current file's message with the edited message after ensuring that an authorised user 
#is attempting to edit the file.
#Also append to the log file with who and what time they edited
#Done by Amit
put '/edit' do
    protected!
    infoH= "#{params[:header]}"
    @infoheader = infoH
    info = "#{params[:message]}"
    @info = info
    file = File.open($currentFile, "w")
    file.puts @info
    file.close
    f = File.open("wikiSubHeading.txt", "w")
    f.puts @infoheader
    f.close
    fi = File.open("log.txt", "r+")
    l = "User: " + $credentials[0] + " edited the wiki at " + Time.now.to_s + "\n"
    @l = l
    fi.puts @l
    fi.close
    redirect '/'
end

get '/login' do
    erb :login
end

#Login and see if the username exists otherwise redirect to no account
#Then match password and if it doesn't match redirect to wrongaccount
#If login is successful store in global variable credentials
#Done by Amit
post '/login' do
    $credentials = [params[:username],params[:password]]
    @Users = User.first(:username => $credentials[0])
    if @Users
        if @Users.password == $credentials[1]
            redirect '/'
        else
            $credentials = [' ',' ']
            redirect '/wrongaccount'
        end
    else
        $credentials = [' ',' ']
        redirect '/noaccount'
    end
end

get '/wrongaccount' do
    erb :wrongaccount
end

get '/user/:uzer' do
    @Userz = User.first(:username => params[:uzer])
    if @Userz != nil
        erb :profile
    else
        redirect '/noaccount'
    end
end

get '/createaccount' do
    erb :createaccount
end

#See if username exists if not then create account with that username
#If attempting to create admin then redirect to admin controls otherwise redirect to thanks
#Done by Amit
post '/createaccount' do
    @Usere =  User.first(:username => params[:username])
    if @Usere != nil
        erb :usernameexists
    else
        n = User.new
        n.username = params[:username]
        n.password = params[:password]
        n.date_joined = Time.now
        if n.username == "Admin" and n.password == "Password"
            n.edit = true
        end
        n.save
        if $credentials[0] == "Admin"
            redirect '/admincontrols'
        else
            $credentials = [params[:username],params[:password]]
            @Users = User.first(:username => $credentials[0])
            redirect '/thanks'
        end
    end
end

get '/logout' do
    $credentials = [' ',' ']
    redirect '/'
end

#Change the ability for the users to edit from Admin Controls
#Done by Amit
put '/user/:uzer' do
    n = User.first(:username => params[:uzer])
    n.edit = params[:edit] ? 1 : 0
    n.save
    redirect '/'
end

#Delete users but checks to ensure that admin is not being destroyed
#and that admin is the one attempting to delete
#then redirect back to admin controls
#Done by Amit
get '/user/delete/:uzer' do
    # protected!
    if $credentials[0] != "Admin"
        erb :denied
    else
        n = User.first(:username => params[:uzer])
        if n.username == "Admin"
            erb :denied
        else
            n.destroy
            @list2 = User.all :order => :id.desc
            erb :admincontrols
        end
    end
end

#list all users
get '/admincontrols' do
    protected!
    @list2 = User.all :order => :id.desc
    erb :admincontrols
end

get '/notfound' do
    erb :notfound
end

get '/noaccount' do
    erb :noaccount
end

get '/denied' do
    erb :denied
end

get '/changepassword' do
    erb :changepassword
end

#Ensure that user is logged in
#Then change password for that user
#Done by Amit
post '/changepassword' do
    if $credentials[0] == " "
        erb :denied
    else
        $credentials[1] = params[:password]
        n = User.first(:username => $credentials[0])
        n.password = params[:password]
        n.save
    end
end

get '/thanks' do
    erb :thanks
end

get '/log' do
    protected!
    file = File.open("log.txt", "r")
    @l = file.read
    file.close
    erb :log
end

get '/archive' do
    if $credentials[0] != "Admin"
        erb :denied
    else
        file = File.open("filenames.txt", "r")
        @filenames = file.read
        file.close
        erb :archive
    end
end

#If the admin chooses to change the file to be displayed then it will replace the currentFile
#global variable with the one they choose
#Done by Amit
post '/archive' do
    filename = params[:name]
    $currentFile = filename
    redirect '/'
end

get '/archivefile' do
    if $credentials[0] != "Admin"
        erb :denied
    else
        file = File.open("filenames.txt", "r")
        @filenames = file.read
        file.close
        erb :archivefile
    end
end

#Save the file as the filename they chose
#Add filename to file "filenames.txt" to have a list of all files
post '/archivefile' do
    file = File.open(params[:name], "w")
    f = File.open($currentFile, "r")
    info = f.read
    file.puts info
    file.close
    f.close
    fi = File.open("filenames.txt", "r+")
    @filenamez = params[:name] + "\n"
    fi.puts @filenamez
    fi.close
    redirect 'admincontrols'
end

not_found do
    status 404
    redirect '/'
end