Gretel::Trails.configure do |config|
  config.store.secret = ENV["SECRET_KEY_BASE"] || '80d782d6b17119ceb1c1177dd1cdd89c6270e22729fe7342ce68290fea23f8d8731826f60ec5d2e40df1901127b7149b660ea83ef0895d9cab74065959163605'
end