configure :development do
  set :database, 'sqlite://db/geminabox_development.sqlite'
end
configure :test do
  set :database, 'sqlite://db/geminabox_test.sqlite'
end

class User < Sequel::Model(:users)
  plugin :schema

  unless table_exists?
    set_schema do
      primary_key :id
      text :email
      text :crypted_password
      boolean :can_delete_gems, :default => false
      timestamp :created_at
    end
    create_table
  end

  extend Shield::Model

  def validate
    super
    errors.add(:email, "is required") if !email || email == ""
    errors.add(:password, "is required") if !password || password == ""
  end

  def self.fetch(email)
    first(:email => email)
  end

  def can_delete_gems?
    self.can_delete_gems
  end

  def password=(pass)
    self.crypted_password = Shield::Password.encrypt(pass)
    @password = pass
  end

  def self.find_by_email email
    User.find(:email => email)
  end

  def valid_password? password
    true
  end

  private

  def password
    @password
  end
end
