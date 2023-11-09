# GPS Tracker TCP Server

## Description

This project is a TCP server designed to communicate with OBD2 trackers installed in vehicles. The server receives data transmitted by the trackers, processes it, and stores it in a structured format. This allows for real-time tracking and analysis of vehicle data, providing valuable insights for fleet management, vehicle diagnostics, and more.

## Installation

To install the project locally, follow these steps:

1. Install Ruby on your Linux machine by running the following command:
    
    ```bash
    sudo apt-get install ruby-full
    ```

2. Clone the repository to your local machine:

    ```bash
    git clone https://github.com/uozalp/GPS-Server.git
    ```

3. Navigate to the project directory:

    ```bash
    cd GPS-Server
    ```

4. Install the required gems:

    ```bash
    bundle install
    ```

5. Start the server:

    ```bash
    ruby TCPServer.rb
    ```

Alternatively, you can set it up as a service using systemd. Here's an example of a systemd service file for the project:
```
[Unit]
Description=OBD2 Tracker
After=network.target

[Service]
Type=simple
User=z-gps
WorkingDirectory=/var/lib/gps
EnvironmentFile=-/var/lib/gps/.environment
ExecStart=/usr/bin/nohup /var/lib/gps/.rvm/rubies/ruby-2.5.1/bin/ruby /var/lib/gps/TCPServer.rb &
ExecStop=/bin/kill -s QUIT $MAINPID
RestartSec=3
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
Save this as `/etc/systemd/system/obd2.service` and give it the appropriate permissions (0644). You can then start the service with `systemctl start obd2.service` and enable it to run at boot with `systemctl enable obd2.service`.


## Database Schema

The project uses a MySQL database named `GPS`. It includes the following tables:

### Coordinates
Fields include: uuid, uuid_text, submitDatetime, vehicleDatetime, ihdr, deviceId, protocol, validity, latitude, longitude, distance, vehicleSpeed, calculatedSpeed, direction, mcc, mnc, lac, cid, performance, hex.

### TCP_Sessions
Fields include: id, deviceId, Thread, TCPSocket, IP, Connected, Keepalive, Closed, Status.

### Vehicles
Fields include: id, make, model, year, vin, license_plate, color, owner_name, owner_phone, owner_email.

## License

This project is licensed under the terms of the MIT license.
