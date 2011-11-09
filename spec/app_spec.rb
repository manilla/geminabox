require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Geminabox do
  before do
    User.dataset.destroy
  end
  describe "/login" do
    it "renders a login form" do
      get "/login"
      last_response.should be_successful
      last_response.should have_tag "input#user_email"
      last_response.should have_tag "input#user_password"
    end
  end
  describe "/logout" do
    it "destroys the users session" do
      user = User.create(email: "a@a.com", password: "asdf1234")
      post '/authenticate', user: {email: "a@a.com", password: "asdf1234"}
      session['User'].should_not be_nil
      get '/logout'
      session['User'].should be_nil
    end
  end
  describe "/authenticate" do
    context "with valid params" do
      it "sets the users id in the session" do
        user = User.create(:email => "a@a.com", :password => "asdf1234")
        post "/authenticate", :user => {:email => "a@a.com", :password => "asdf1234"}
        session['User'].should == user.id
        last_response.should be_redirect
        get '/'
        last_response.body.should match "Upload Another Gem"
      end
    end
    context "with invalid params" do
      it "shows the login page" do
        post "/authenticate", :user => {:email => "asdf", :password => "asdf"}
        session['User'].should be_nil
        last_response.should be_redirect
      end
    end
  end
  describe "/register" do
    it "displays a registration form" do
      get '/register'
      last_response.should be_successful
      last_response.should have_tag "input#email"
      last_response.should have_tag "input#password"
      last_response.should have_tag "input#password_confirmation"
      last_response.should have_tag "input[type=submit][value=Register]"
    end
  end
  describe "/do_register" do
    context "with good params" do
      it "creates a new user" do
        post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: "asdf"
        User.find_by_email("a@a.com").should be_a User
      end
    end
    context "with bad params" do
      context "with no email" do
        it "renders the correct validation message" do
          post '/do_register', email: "", password: "asdf", password_confirmation: "asdf"
          last_response.should be_successful
          last_response.body.should match "email is required"
        end
      end
      context "with no password" do
        it "renders the correct validation mesage" do
          post '/do_register', email: "a@a.com", password: "", password_confirmation: "asdf"
          last_response.should be_successful
          last_response.body.should match "password does not match confirmation"
        end
      end
      context "with no password confirmation" do
        it "renders the correct validation message" do
          post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: ""
          last_response.should be_successful
          last_response.body.should match "password does not match confirmation"
        end
      end
      context "with an unmatched password confirmation" do
        it "renders the correct validation message" do
          post '/do_register', email: "a@a.com", password: "asdf", password_confirmation: "asdf1234"
          last_response.should be_successful
          flash[:error].should match "password does not match confirmation"
          last_response.body.should match "password does not match confirmation"
        end
      end
    end
  end
  describe "/" do
    context "without logging in" do
    it "requires authentication" do
      get "/"
      last_response.should be_redirect
    end
    end
    context "after logging in" do
      before do
        @user = User.create(email: "a@a.com", password: "asdf")
        post '/authenticate', user: {email: "a@a.com", password: "asdf"}
      end
      it "renders the gem index" do
        get "/"
        last_response.should be_successful
        last_response.should match "Upload"
      end
    end
  end

  describe "/upload" do
    context "with incorrect basic auth params" do
      before do
        Geminabox.any_instance.stubs(:basic_auth_credentials).returns(['not', 'test'])
      end
      it "returns not authorized" do
        basic_authorize 'first', 'test'
        post '/upload'
        last_response.status.should == 401
      end
      it "doesn't blow up without authorization" do
        post '/upload'
        last_response.status.should == 401
      end
    end
    context "with correct basic auth params" do
      before do
        Geminabox.any_instance.stubs(:basic_auth_credentials).returns(['basic', 'auth'])
      end
      it "allows upload" do
        # TODO: This spec blows.  Requires building the gem to pass
        basic_authorize 'basic', 'auth' #-- Rack::Test
        post '/upload', :file => Rack::Test::UploadedFile.new(File.expand_path(File.join(__FILE__, '..', '..', 'geminabox-0.3.2.manilla.gem')), 'application', true)
        last_response.status.should == 200
      end
    end
  end

  describe "/gems/*.gem" do
    context "when current user has delete gem permission" do
      before do
        @user = User.new(email: "a@a.com", password: "asdf")
        @user.can_delete_gems = true
        @user.save
        post '/authenticate', user: {email: "a@a.com", password: "asdf"}
      end
      it "succeeds" do
        Geminabox.any_instance.stubs(:file_path)
        Geminabox.any_instance.stubs(:reindex)
        File.expects(:exists?).returns(true)
        File.expects(:delete).returns(true)
        delete "/gems/test.gem"
        last_response.should be_redirect
      end
    end
    context "when current user does not have delete gem permission" do
      before do
        @user = User.create(email: "a@a.com", password: "asdf")
        post '/authenticate', user: {email: "a@a.com", password: "asdf"}
      end
      it "renders permission unauthorized" do
        File.expects(:exists?).never
        File.expects(:delete).never
        delete "/gems/test.gem"
        last_response.should be_redirect
        flash[:error].should match "You don't have permission to do that!"
      end
    end
  end
end
