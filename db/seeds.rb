# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).


# insert dummy admin
User.create!(
  name: "Test Admin",
  email: "test@pixelpoint.at",
  admin: true,
  password:"password"
)
