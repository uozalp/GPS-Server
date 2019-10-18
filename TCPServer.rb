require 'socket'
require 'mysql2'
require 'digest'
require 'date'
require "net/https"


portnumber = 9000
socketServer = TCPServer.open(portnumber)

class IO
  def while_reading(data = nil)
    while buf = readpartial_rescued(1024)
      data << buf  if data
      yield buf  if block_given?
    end
    data
  end
 
  private
 
  def readpartial_rescued(size)
    readpartial(size)
  rescue EOFError
    nil
  end
end


def AddToLog(string)
	puts "#{string}"
	Dir.mkdir './logs' unless File.directory?("./logs")
  open("./logs/#{Time.now.strftime('%Y-%m-%d')}.txt", "a") { |f| f.puts "#{string}\n" }
end


def query(str, arr)
  begin
    con = Mysql2::Client.new(:host => "#{ENV['x_host']}", :username => "#{ENV['x_username']}", :password => "#{ENV['x_password']}", :database => "#{ENV['x_database']}")

    st = con.prepare(str)
    st.execute(*arr)
    
  rescue Mysql2::Error => e
    puts "#{e.errno} #{e.error}"
  ensure
    con.close if con
  end
end


def distanceCheck(a, b)
  rad_per_deg = Math::PI/180  # PI / 180
  rkm = 6371                  # Earth radius in kilometers
  rm = rkm * 1000             # Radius in meters

  dlon_rad = (b[1]-a[1]) * rad_per_deg  # Delta, converted to rad
  dlat_rad = (b[0]-a[0]) * rad_per_deg

  lat1_rad, lon1_rad = a.map! {|i| i * rad_per_deg }
  lat2_rad, lon2_rad = b.map! {|i| i * rad_per_deg }

  a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
  c = 2 * Math.asin(Math.sqrt(a))
  
  return (rm * c) # Delta in meters
end


def pushover(title, message)

  if(Thread.current['DEBUG'] == true)
  
    url = URI.parse("https://api.pushover.net/1/messages")
    req = Net::HTTP::Post.new(url.path)
    req.set_form_data({
      :token => "#{ENV['x_push_token']}",
      :user => "#{ENV['x_push_user']}",
      :title => title,
      :message => message
    })
    res = Net::HTTP.new(url.host, url.port)
    res.use_ssl = true
    res.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res.start {|http| http.request(req) }
    
  end
  
end


def engineOn(inputDate)

  if(Thread.current['COUNT'] == nil)

    Thread.current['COUNT'] = Array.new
    Thread.current['COUNT'].push(DateTime::strptime(inputDate, "%H%M%S%d%m%y").to_datetime)

  else

    # Previous vehicle time (UTC)
    previousTime = Thread.current['COUNT'].last
    
    # Current vehicle time (UTC)
    currentTime = DateTime::strptime(inputDate, "%H%M%S%d%m%y").to_datetime

    diff = ((currentTime - previousTime) * 24 * 60 * 60).to_i

    if((currentTime > previousTime) and (diff < 30) and (diff >= 5))

      Thread.current['COUNT'].push(currentTime)

    else

      # clear array
      Thread.current['COUNT'] = Array.new
      Thread.current['COUNT'].push(DateTime::strptime(inputDate, "%H%M%S%d%m%y").to_datetime)

    end

  end

  return Thread.current['COUNT'].count == 3 ? true : false

end


def bin_to_hex(s)
  s.each_byte.map { |b| "%02x" % b.to_i }.join(' ')
end


query("UPDATE TCP_Sessions SET Status=? WHERE Status='ESTABLISHED'", ['CLOSED'])

puts "\e[H\e[2JRuby TCP server"
while true
  Thread.new(socketServer.accept) do |connection|

    if(connection.peeraddr[2].to_s != "127.0.0.1")
      AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - #{connection.peeraddr[2]} - #{connection} - Connected")
      param = [Thread.current.to_s, connection.to_s, connection.peeraddr[2].to_s]
      query("INSERT INTO TCP_Sessions (Thread, TCPSocket, IP, Connected, Status) VALUES(?, ?, ?, NOW(), 'ESTABLISHED')", param)
    end
  
    begin
      connection.while_reading do |buf|

          # Performance timer
          start = Time.now

          case bin_to_hex(buf.chomp)[0..1]
          when "32"
            ############
            # 0x32 = 2 #
            ############
            
            # Exit old running threads
            if(buf.match(/(231d9ddb746f79ece7c1a9c046c96439d4b103b5)/))
              if(buf.match(/(231d9ddb746f79ece7c1a9c046c96439d4b103b5:kill)/))
                input = buf.match(/231d9ddb746f79ece7c1a9c046c96439d4b103b5:kill:(#<Thread:.*>)/).captures
                Thread.list.each do |thr|
                  if(input[0].to_s == thr.to_s)
                    thr.exit unless (thr == Thread.current or thr == Thread.main)
                  end
                end
              end
              if(buf.match(/(231d9ddb746f79ece7c1a9c046c96439d4b103b5:list)/))
                Thread.list.each do |thr|
                  connection.puts "#{thr.to_s}" unless (thr == Thread.current or thr == Thread.main)
                end
              end
            end
            Thread.current.exit
            
          when "2a"
            ############
            # 0x2a = * #
            ############
            
            AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - Debug: #{buf.chomp}")
            
            d = buf.chomp.match(/(?<ihdr>.+),(?<device>\d{10}),(?<protocol>.+),(?<time>\d{6}),(?<validity>[ABV]),(?<dd>\d{2})(?<lat_min>\d{2}[.]\d{4}),(?<NS>[NS]),(?<ddd>\d{3})(?<lon_min>\d{2}[.]\d{4}),(?<EW>[EW]),(.*),(?<speed>\d{3}),(?<date>\d{6}),(?<vehicle>[0-9a-fA-F]+),(?<mcc>\d+),(?<mnc>\d+),(?<lac>\d+),(?<cid>\d+)#/)          
            
            unless d.nil?

              latitude    = "#{d[ 'dd'].to_i}.#{((d['lat_min'].to_f / 60)*1000000).to_i}"
              longitude   = "#{d['ddd'].to_i}.#{((d['lon_min'].to_f / 60)*1000000).to_i}"

              if(d['NS'] == "S") then latitude = latitude.to_f * -1 end
              if(d['EW'] == "W") then longitude = longitude.to_f * -1 end

              vehicleDatetime = DateTime::strptime("#{d['time']}#{d['date']}", "%H%M%S%d%m%y").strftime("%Y-%m-%d %H:%M:%S")
                      
              if(Thread.current['DEVICE'].nil?)

                Thread.current['DEVICE'] = d['device']
                query("UPDATE TCP_Sessions SET deviceId=? WHERE TCPSocket=?", [Thread.current['DEVICE'], connection.to_s])

                st = query("SELECT identifier, debug FROM Vehicles WHERE identifier=? LIMIT 1", [Thread.current['DEVICE']])

                #Thread.current['LATITUDE']   = latitude
                #Thread.current['LONGITUDE']  = longitude
                #Thread.current['TIMESTAMP']  = vehicleDatetime.to_datetime

                st.each do |row|
                  if(row['debug'] == 1)
                    Thread.current['DEBUG'] = true
                  end
                end

                # Check for previous disconnected session
                Thread.list.each do |xthr|
                  if((xthr['DEVICE'] == Thread.current['DEVICE']) and (xthr != Thread.current))
                    Thread.current['DEBUG']         = xthr['DEBUG'] unless xthr['DEBUG'].nil?
                    Thread.current['ENGINE']        = xthr['ENGINE'] unless xthr['ENGINE'].nil?
                    Thread.current['ENGINE-STOP']   = xthr['ENGINE-STOP'] unless xthr['ENGINE-STOP'].nil?
                    Thread.current['ENGINE-START']  = xthr['ENGINE-START'] unless xthr['ENGINE-START'].nil?
                    Thread.current['LATITUDE']      = xthr['LATITUDE'] unless xthr['LATITUDE'].nil?
                    Thread.current['LONGITUDE']     = xthr['LONGITUDE'] unless xthr['LONGITUDE'].nil?
                    Thread.current['TIMESTAMP']     = xthr['TIMESTAMP'] unless xthr['TIMESTAMP'].nil?
                    xthr.exit unless (xthr == Thread.current or xthr == Thread.main)
                  end
                end
                
              end
                  
              param = [vehicleDatetime, d['ihdr'], d['device'], d['protocol'], d['validity'], latitude, longitude, d['mcc'], d['mnc'], d['lac'], d['cid'], (Time.now - start)*1000.0]
              query("INSERT INTO Coordinates(uuid, submitDatetime, vehicleDatetime, ihdr, deviceId, protocol, validity, latitude, longitude, mcc, mnc, lac, cid, performance) VALUES(unhex(replace(uuid(),'-','')), UTC_TIMESTAMP(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", param)
              
            end

          when "24"
            ############
            # 0x24 = $ #
            ############

            AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - HEX: #{bin_to_hex(buf.chomp)}")

            # Data input
            hexArr = (bin_to_hex(buf.chomp)).split(" ")


            deviceId = hexArr[1..5].join('')
            vehicleDatetime = DateTime::strptime("#{hexArr[6..11].join('')}", "%H%M%S%d%m%y").strftime("%Y-%m-%d %H:%M:%S")
            vehicleSpeed = (hexArr[22..24].join('')[0..2]).to_i * 1.852
            direction = hexArr[22..24].join('')[3..5]

            mcc = hexArr[38].to_i(16)
            mnc = hexArr[39].to_i(16)
            lac = hexArr[40..41].join('').to_i(16)
            cid = hexArr[42..43].join('').to_i(16)


            # Latitude
            lat = hexArr[12..15].join('').match(/(?<degree>\d{2})(?<min>\d{6})/)
            latitude = "#{lat['degree'].to_i}.#{( (lat['min'].to_f / 60) * 100).to_i}";
            if(hexArr[21].hex.to_s(2).rjust(hexArr[21].size*4, '0').to_i(2)[2].to_s == "0")
              # bit: 0100
              latitude = latitude.to_f * -1
            end


            # Longitude
            lon = hexArr[17..21].join('').match(/(?<degree>\d{3})(?<min>\d{6})/)
            longitude =  "#{lon['degree'].to_i}.#{( (lon['min'].to_f / 60) * 100).to_i}";
            if(hexArr[21].hex.to_s(2).rjust(hexArr[21].size*4, '0').to_i(2)[3].to_s == "0")
              # bit: 1000
              longitude = longitude.to_f * -1
            end


            # Validity - bit: 0010
            if(hexArr[21].hex.to_s(2).rjust(hexArr[21].size*4, '0').to_i(2)[1].to_s == "1")
              validity = "A"
            else 
              validity = "V"
            end


            # Current UTC time
            date1 = Time.now.utc.to_datetime

            # Vehicle time of last movent
            date2 = DateTime::strptime("#{hexArr[6..11].join('')}", "%H%M%S%d%m%y").to_datetime

            diff = ((date1 - date2) * 24 * 60 * 60).to_i

            unless Thread.current['ENGINE-STOP'].nil?
              lastStart = ((date1 - Thread.current['ENGINE-STOP']) * 24 * 60 * 60).to_i
            end


            # Calculate distance
            if(Thread.current['LATITUDE'].nil? or Thread.current['LONGITUDE'].nil?)
              distanceInMeters = 0.0
              calculatedSpeed = 0.0
            else
              distanceInMeters = distanceCheck([latitude.to_f, longitude.to_f], [Thread.current['LATITUDE'].to_f, Thread.current['LONGITUDE'].to_f])
              differenceInSeconds = ((date2 - Thread.current['TIMESTAMP']) * 24 * 60 * 60).to_i
              calculatedSpeed = ((distanceInMeters / differenceInSeconds) * 3600 ) / 1000
            end

            # Save lat, long in thread
            Thread.current['LATITUDE']  = latitude
            Thread.current['LONGITUDE'] = longitude
            Thread.current['TIMESTAMP'] = date2


            if(diff >= 100)
              if(Thread.current['ENGINE'] == "ON" )
                if(date2 > Thread.current['ENGINE-START'])
                  Thread.current['ENGINE'] = "OFF"
                  Thread.current['ENGINE-STOP'] = date1
                  Thread.current['ENGINE-START'] = nil
                  Thread.current['COUNT'] = nil
                  pushover("Salesbird", "Bilen er slukket\nDevice: #{Thread.current['DEVICE']} \nDate: #{date1} \nOBD: #{date2} \nDiff: #{diff} seconds\nThread: #{Thread.current.to_s.match(/#<Thread:(0[xX][0-9a-fA-F]+)/).captures[0]}\nConnection: #{connection.to_s.match(/#<TCPSocket:(0[xX][0-9a-fA-F]+)/).captures[0]}\nURL: https://www.google.dk/maps/search/#{latitude},#{longitude}");
                end
              end
            else
              if(Thread.current['ENGINE'] != "ON" and (Thread.current['ENGINE-STOP'].nil? or lastStart > 90))
                if(engineOn("#{hexArr[6..11].join('')}"))
                  Thread.current['ENGINE'] = "ON"
                  Thread.current['ENGINE-START'] = date2
                  Thread.current['ENGINE-STOP'] = nil
                  pushover("Salesbird", "Bilen er startet\nDevice: #{Thread.current['DEVICE']} \nDate: #{date1} \nOBD: #{date2} \nDiff: #{diff} seconds\nThread: #{Thread.current.to_s.match(/#<Thread:(0[xX][0-9a-fA-F]+)/).captures[0]}\nConnection: #{connection.to_s.match(/#<TCPSocket:(0[xX][0-9a-fA-F]+)/).captures[0]}\nURL: https://www.google.dk/maps/search/#{latitude},#{longitude}");
                end
              end
            end

            param = [vehicleDatetime, deviceId, 'REALTIME', validity, latitude, longitude, distanceInMeters, vehicleSpeed, calculatedSpeed, direction, mcc, mnc, lac, cid, (Time.now - start)*1000.0, bin_to_hex(buf.chomp)]
            query("INSERT INTO Coordinates(uuid, submitDatetime, vehicleDatetime, deviceId, protocol, validity, latitude, longitude, distance, vehicleSpeed, calculatedSpeed, direction, mcc, mnc, lac, cid, performance, hex) VALUES(unhex(replace(uuid(),'-','')), UTC_TIMESTAMP(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", param)

          when "58"
            ############
            # 0x58 = X #
            ############

            AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - X: #{bin_to_hex(buf.chomp)}")
            Thread.current.exit

          else
            #############
            # catch all #
            #############
            
            AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - ALL: #{bin_to_hex(buf.chomp)}")
            Thread.current.exit

          end

          # Keepalive
          query("UPDATE TCP_Sessions SET Keepalive=NOW() WHERE TCPSocket=?", [connection.to_s])

      end
    rescue Exception => e
      # Displays Error Message
      AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - #{connection.peeraddr[2]} - #{connection} - #{ e } (#{ e.class })")
    ensure
      AddToLog("#{Time.now.strftime('%d/%m/%Y %H:%M:%S')} - #{connection.peeraddr[2]} - #{connection} - ensure: Closing")
      query("UPDATE TCP_Sessions SET Status=?, Closed=NOW() WHERE TCPSocket=?", ['CLOSED', connection.to_s])
      Thread.current.exit
    end
  end
end