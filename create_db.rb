require "sqlite3"

db = SQLite3::Database.new 'ridesharing.db'

# Create the data model

# Customers: have ID, name and number
db.execute <<-SQL
  CREATE TABLE customers (id INTEGER PRIMARY KEY, name TEXT, number TEXT)
SQL

# Drivers: have ID, name and number
db.execute <<-SQL
  CREATE TABLE drivers (id INTEGER PRIMARY KEY, name TEXT, number TEXT)
SQL

# Proxy Numbers: have ID and number
db.execute <<-SQL
  CREATE TABLE proxy_numbers (id INTEGER PRIMARY KEY, number TEXT)
SQL

# Rides: have ID, start, destination and date; are connected to a customer, a driver, and a proxy number
db.execute <<-SQL
  CREATE TABLE rides (id INTEGER PRIMARY KEY, start TEXT, destination TEXT, datetime TEXT, customer_id INTEGER, driver_id INTEGER, number_id INTEGER, FOREIGN KEY (customer_id) REFERENCES customers(id), FOREIGN KEY (driver_id) REFERENCES drivers(id))
SQL

# Insert some data

# Create a sample customer for testing
# -> enter your name and number here!
db.execute("INSERT INTO customers (name, number) VALUES ('Caitlyn Carless', '31970XXXX')")

# Create a sample driver for testing
# -> enter your name and number here!
db.execute("INSERT INTO drivers (name, number) VALUES ('David Driver', '31970YYYY')")

# Create a proxy number
# -> provide a number purchased from MessageBird here
# -> copy the line if you have more numbers
db.execute("INSERT INTO proxy_numbers (number) VALUES ('31970ZZZZ')");
