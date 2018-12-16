require 'dotenv'
require 'sinatra'
require 'messagebird'
require 'sqlite3'

set :root, File.dirname(__FILE__)

# Initialize database
DB = SQLite3::Database.open('./ridesharing.db')

#  Load configuration from .env file
Dotenv.load if Sinatra::Base.development?

# Load and initialize MesageBird SDK
client = MessageBird::Client.new(ENV['MESSAGEBIRD_API_KEY'])

# Show admin interface
get '/' do
  # Find unassigned proxy numbers
  proxy_numbers = DB.execute('SELECT number FROM proxy_numbers')

  # Find current rides
  rides = DB.execute('SELECT c.name AS customer, d.name AS driver, start, destination, datetime, p.number AS number FROM rides r JOIN customers c ON c.id = r.customer_id JOIN drivers d ON d.id = r.driver_id JOIN proxy_numbers p ON p.id = r.number_id')

  # Collect customers
  customers = DB.execute('SELECT * FROM customers')

  # Collect drivers
  drivers = DB.execute('SELECT * FROM drivers')

  return erb :admin, locals: {
    proxy_numbers: proxy_numbers,
    rides: rides,
    customers: customers,
    drivers: drivers
  }
end

# Create a new ride
post '/createride' do
  # Find customer details
  customer = DB.execute('SELECT * FROM customers WHERE id = ?', params['customer']).first

  # Find driver details
  driver = DB.execute('SELECT * FROM drivers WHERE id = ?', params['driver']).first

  # Find a number that has not been used by the driver or the customer
  proxy_number = DB.execute('''
    SELECT * FROM proxy_numbers
    WHERE id NOT IN (SELECT number_id FROM rides WHERE customer_id = ?)
    AND id NOT IN (SELECT number_id FROM rides WHERE driver_id = ?)
    ''', customer[0], driver[0]).first

  return 'No number available! Please extend your pool.' if proxy_number.nil?

  # Store ride in database
  DB.execute('INSERT INTO rides (start, destination, datetime, customer_id, driver_id, number_id) VALUES (?, ?, ?, ?, ?, ?)',
             params['start'],
             params['destination'],
             params['datetime'],
             customer[0],
             driver[0],
             proxy_number[0])

  #  Notify the customer
  client.message_create(proxy_number[1], [customer[2]], "#{driver[1]} will pick you up at #{params['datetime']}. Reply to this message to contact the driver.")

  # Notify the driver
  client.message_create(proxy_number[1], [driver[2]], "#{customer[1]} will wait for you at #{params['datetime']}. Reply to this message to contact the customer.")

  # Redirect back to previous view
  redirect '/'
end

# Handle incoming messages
post '/webhook' do
  # Read input sent from MessageBird
  number = params['originator']
  text = params['params']
  proxy = params['recipient']

  row = DB.execute('''
    SELECT c.number AS customer_number, d.number AS driver_number, p.number AS proxy_number
    FROM rides r JOIN customers c ON r.customer_id = c.id JOIN drivers d ON r.driver_id = d.id JOIN proxy_numbers p ON p.id = r.number_id
    WHERE proxy_number = ? AND (driver_number = ? OR customer_number = ?''', proxy, number, number)

  unless row
    puts "Could not find a ride for customer/driver #{number} that uses proxy #{proxy}."
  end

  # Need to find out whether customer or driver sent this and forward to the other side
  recipient = number == row[0] ? row[1] : row[0]

  # Forward the message through the MessageBird API
  client.message_create(proxy, [recipient], text)
  status 200
  body ''
end

# Handle incoming calls
get '/webhook-voice' do
  # Read input sent from MessageBird
  number = params['source']
  proxy = params['destination']

  # Answer will always be XML
  content_type 'application/xml'

  row = DB.execute('''
    SELECT c.number AS customer_number, d.number AS driver_number, p.number AS proxy_number
    FROM rides r JOIN customers c ON r.customer_id = c.id JOIN drivers d ON r.driver_id = d.id JOIN proxy_numbers p ON p.id = r.number_id
    WHERE proxy_number = ? AND (driver_number = ? OR customer_number = ?)''', proxy, number, number)

  # Cannot match numbers
  if row.empty?
    return '''<?xml version="1.0" encoding="UTF-8"?>
    <Say language="en-GB" voice="female">Sorry, we cannot identify your transaction. Make sure you call in from the number you registered.</Say>
    '''
  end

  # Need to find out whether customer or driver sent this and forward to the other side
  recipient = number == row[0] ? row[1] : row[0]

  # Create call flow to instruct transfer
  puts "Transferring call to #{recipient}"

  return """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <Transfer destination=\"#{recipient}\" mask=\"true\" />
  """
end
