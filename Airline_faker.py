import pyodbc
import random
import string
from datetime import datetime, timedelta

try:
    conn = pyodbc.connect(
        'DRIVER={SQL Server};SERVER=MUHAMMAD_AWAIS\\SQLEXPRESS;DATABASE=Airline;Trusted_Connection=yes')
    print("Connected to database successfully!")
    cursor = conn.cursor()

    # List of Islamic/Pakistani male names
    male_names = ["Muhammad", "Ahmed", "Ali", "Hassan", "Omar", "Abdullah"]

    # List of Islamic/Pakistani female names
    female_names = ["Ayesha", "Fatima", "Zainab", "Sana", "Maham", "Maryam"]

    # List of Islamic/Pakistani last names
    last_names = ["Khan", "Ahmed", "Riaz", "Siddiqui", "Malik", "Iqbal"]

    Aircraft_name = [
        "Boeing 747", "Airbus A380", "Lockheed C-130 Hercules", "Boeing 737", "Airbus A320", "Boeing 777",
        "Boeing 787 Dreamliner", "Cessna 172", "Embraer E190",
        "Gulfstream G650", "Bombardier Global 6000", "Airbus A350", "Boeing 757", "McDonnell Douglas F-15 Eagle",
        "Sukhoi Su-27", "Lockheed Martin F-22 Raptor",
        "Boeing AH-64 Apache", "Eurofighter Typhoon", "Boeing F/A-18 Super Hornet", "Lockheed Martin F-35 Lightning II"]

    cities = [
        "Karachi", "Lahore", "Islamabad", "Faisalabad", "Rawalpindi", "Multan", "Peshawar", "Quetta", "Gujranwala",
        "Hyderabad",
    ]
    # List of designations
    designations = ["Pilot", "Co-Pilot", "Air Hostess", "Flight Attendant", "Ground Staff", "Security Personnel"]


    class AirlineFaker:

        # for unique ids
        passengers_id = set()
        admin_ids = set()
        staff_ids = set()
        aircraft_ids = set()
        flight_ids = set()
        ticket_ids = set()
        booking_ids = set()
        payment_ids = set()
        assg_ids = set()

        # for additional
        used_phn = set()
        used_email = set()
        ticket_prices = dict()

        # for foriegn keys
        aircraftFkset = set()
        ticketsFkset = set()

        @staticmethod
        def passenger_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.passengers_id:
                    AirlineFaker.passengers_id.add(new_id)
                    return f"P-{new_id}"

        @staticmethod
        def cnicGen():
            return f"{random.randint(10000, 99999)}-{random.randint(1000000, 9999999)}-{random.randint(1, 9)}"

        @staticmethod
        def passportGen():
            letters = ''.join(random.choices(string.ascii_uppercase, k=2))
            numbers = ''.join(random.choices(string.digits, k=7))
            return letters + numbers

        @staticmethod
        def admin_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.admin_ids:
                    AirlineFaker.admin_ids.add(new_id)
                    return f"Ad-{new_id}"

        @staticmethod
        def staff_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.staff_ids:
                    AirlineFaker.staff_ids.add(new_id)
                    return f"S-{new_id}"

        @staticmethod
        def aircraft_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.aircraft_ids:
                    AirlineFaker.aircraft_ids.add(new_id)
                    # AirlineFaker.aircraftFk.append(f"A-{new_id}")
                    return f"A-{new_id}"

        @staticmethod
        def flight_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.flight_ids:
                    AirlineFaker.flight_ids.add(new_id)
                    return f"F-{new_id}"

        @staticmethod
        def ticket_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.ticket_ids:
                    AirlineFaker.ticket_ids.add(new_id)
                    return f"Tk-{new_id}"

        @staticmethod
        def booking_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.booking_ids:
                    AirlineFaker.booking_ids.add(new_id)
                    return f"Bk-{new_id}"

        @staticmethod
        def payment_id():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.payment_ids:
                    AirlineFaker.payment_ids.add(new_id)
                    return f"P-{new_id}"

        @staticmethod
        def AssignmentiD():
            while True:
                new_id = random.randint(1, 100000000)
                if new_id not in AirlineFaker.assg_ids:
                    AirlineFaker.assg_ids.add(new_id)
                    return f"Asg-{new_id}"

        @staticmethod
        def firstName():
            # Randomly choosing male or female
            if random.choice([True, False]):
                return random.choice(male_names)
            else:
                return random.choice(female_names)

        @staticmethod
        def lastname():
            return random.choice(last_names)

        @staticmethod
        def phoneGen():
            while True:
                phn = f"+92-{random.randint(300, 399)}-{random.randint(1000000, 9999999)}"
                if phn not in AirlineFaker.used_phn:
                    AirlineFaker.used_phn.add(phn)
                    return phn

        @staticmethod
        def emailGen(first_name):
            while True:
                mail = f"{first_name}{random.randint(0, 100000)}@{random.choice(['gmail.com', 'yahoo.com', 'hotmail.com'])}"
                if mail not in AirlineFaker.used_email:
                    AirlineFaker.used_email.add(mail)
                    return mail

        @staticmethod
        def addressGen():
            city = random.choice(["Karachi", "Lahore", "Islamabad", "Rawalpindi", "Faisalabad"])
            street = f"{random.randint(1, 999)} {random.choice(['Street', 'Road', 'Avenue'])}"
            return f"{street}, {city}"

        @staticmethod
        def gender(first_name):
            if first_name in male_names:
                return "Male"
            else:
                return "Female"

        @staticmethod
        def dobGen():
            start_date = datetime(1950, 1, 1)
            end_date = datetime(2005, 1, 1)
            random_dob = start_date + timedelta(days=random.randint(0, (end_date - start_date).days))
            return random_dob.strftime("%Y-%m-%d")

        @staticmethod
        def designationGen():
            return random.choice(designations)

        @staticmethod
        def MaintenainceGen():
            start_date = datetime(2024, 1, 1)
            end_date = datetime(2024, 12, 31)
            random_dob = start_date + timedelta(days=random.randint(0, (end_date - start_date).days))
            return random_dob.strftime("%Y-%m-%d")

        @staticmethod
        def ArrivalDate(departure_date):
            end_date = datetime(2024, 12, 31)
            max_arrival_date = min(end_date, departure_date + timedelta(days=2))
            return AirlineFaker.generate_random_date(departure_date, max_arrival_date)

        @staticmethod
        def generate_random_date(start_date, end_date):
            # Get the total number of seconds between the start and end dates
            total_seconds = int((end_date - start_date).total_seconds())
            # Generate a random number of seconds between 0 and the total number of seconds
            random_seconds = random.randint(0, total_seconds)
            # Add the random number of seconds to the start date
            random_date = start_date + timedelta(seconds=random_seconds)
            return random_date

        @staticmethod
        def aircraft_capacity(aircraft_id):
            Capacity = random.randint(200, 500)
            # AirlineFaker.aircraftCapacity.update({aircraft_id: Capacity})
            return Capacity

        @staticmethod
        def get_aircraft_capacity(aircraft_id):
            cursor.execute("SELECT Capacity FROM AIRCRAFTS WHERE Ac_id = ?", aircraft_id)
            capacity = cursor.fetchone()[0]
            return capacity

        # Add ticket IDs and prices
        @staticmethod
        def add_ticket_price(ticket_id, price):
            if ticket_id not in AirlineFaker.ticket_prices:
                AirlineFaker.ticket_prices[
                    ticket_id] = price  # Initialize the price for the ticket ID if it doesn't exist
            else:
                AirlineFaker.ticket_prices[
                    ticket_id] += price  # Add the new price to the existing price associated with the ticket ID

        @staticmethod
        def generate_flight_date(tk_id):

            # Retrieve the ticket generated time
            cursor.execute("SELECT Ticket_Generated FROM Tickets WHERE Tkt_id = ?", (tk_id,))
            ticket_generated = cursor.fetchone()[0]

            # Add 3-4 days to the ticket_generated time to get the flight date
            additional_days = random.randint(3, 4)
            flight_date = ticket_generated + timedelta(days=additional_days)

            # Return the flight date as a string
            return flight_date.strftime("%Y-%m-%d %H:%M:%S")


    # function to insert data
    # added arrtibutes cnic
    def passengers_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Passengers (Passenger_id, Fname, lname, gender, address, phone, email, DateOfBirth,Cnic,passport_no) VALUES ( ?, ?, ?, ?, ?, ?, ?,?,?,?)"

        passenger_id = AirlineFaker.passenger_id()
        firstname = AirlineFaker.firstName()
        cnic = AirlineFaker.cnicGen()
        passport = AirlineFaker.passportGen()
        # executing the query
        cursor.execute(sql_query, (
            passenger_id, firstname, AirlineFaker.lastname(), AirlineFaker.gender(firstname),
            AirlineFaker.addressGen(), AirlineFaker.phoneGen(), AirlineFaker.emailGen(firstname),
            AirlineFaker.dobGen(), cnic, passport))
        # Commit the transaction
        conn.commit()


    # no change
    def admins_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Admins (Admin_id, Fname, lname, gender,address,phone,email,DateOfBirth) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"

        # Randomly choosing male or female
        if random.choice([True, False]):
            firstname = random.choice(male_names)
        else:
            firstname = random.choice(female_names)

        # executing the queryy
        cursor.execute(sql_query, (
            AirlineFaker.admin_id(), firstname, AirlineFaker.lastname(), AirlineFaker.gender(firstname),
            AirlineFaker.addressGen(), AirlineFaker.phoneGen(), AirlineFaker.emailGen(firstname),
            AirlineFaker.dobGen()))
        # Commit the transaction
        conn.commit()


    # implemented composite pk,removed qualification
    def staff_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Crew_Staff(Staff_id,FName, lname, gender,address,phone,email,DateOfBirth,Designation) VALUES (?, ?,?, ?, ?, ?, ?,?,?)"

        firstname = AirlineFaker.firstName()

        # executing the query
        cursor.execute(sql_query, (
            AirlineFaker.staff_id(), firstname, AirlineFaker.lastname(), AirlineFaker.gender(firstname),
            AirlineFaker.addressGen(), AirlineFaker.phoneGen(), AirlineFaker.emailGen(firstname),
            AirlineFaker.dobGen(), AirlineFaker.designationGen()))
        # Commit the transaction
        conn.commit()


    # no change
    def aircraft_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Aircrafts(Ac_id,Aircraft_Name,Model,Capacity) VALUES (?, ?, ?,?)"

        ac_id = AirlineFaker.aircraft_id()
        # AirlineFaker.aircraftFk.append(ac_id)

        ac_name = random.choice(Aircraft_name)

        ac_model = random.randint(2000, 2024)

        MaintenanceStatus = random.choice(["OK", "MAINTENANCE REQUIRED"])

        # executing the query
        cursor.execute(sql_query, (
            ac_id, ac_name, ac_model, AirlineFaker.aircraft_capacity(ac_id)))
        # Commit the transaction
        conn.commit()


    def ticket_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Tickets(Tkt_id,Class,Ticket_from,Ticket_to) VALUES (?,?, ?, ?)"

        Class = random.choice(["Business", "Economy"])
        Ticket_from = random.choice(cities)
        Price = random.randint(1000, 10000)

        while True:
            global Ticket_to
            check = random.choice(cities)
            if check != Ticket_from:
                Ticket_to = check
                break

        #if Class != "Economy":
            #Price = random.randint(Price + 1, 20000)

        ticket_id = AirlineFaker.ticket_id()
        # AirlineFaker.ticketFk.append(ticket_id)
        #AirlineFaker.add_ticket_price(ticket_id, Price)

        # executing the query
        cursor.execute(sql_query, (
            ticket_id, Class, Ticket_from, Ticket_to))
        # Commit the transaction
        conn.commit()

    def generate_random_seat_number(flight_id):
        # Get the capacity of the aircraft corresponding to the flight id
        cursor.execute(
            "SELECT Capacity FROM Aircrafts WHERE Ac_id IN (SELECT Ac_id FROM Flight_Schedule WHERE Flight_id = ?)",
            (flight_id,))
        capacity = cursor.fetchone()[0]

        # Generate a random seat number within the capacity of the aircraft
        return random.randint(1, capacity)
    def bookings_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Bookings(Bk_id,Passenger_id,Tkt_id, PaymentMethod,AmountPaid,Flight_id,BookingDate,Seat_No) VALUES (?, ?, ?, ?,?,?,?,?)"

        cursor.execute("SELECT Passenger_id FROM Passengers")
        passengers_id_tuple = cursor.fetchall()
        selected_user_id = random.choice(passengers_id_tuple)
        passenger_id = selected_user_id[0]

        cursor.execute("SELECT tkt_id FROM Tickets")
        ticket_ids_tuple = cursor.fetchall()
        selected_ticket_id = random.choice(ticket_ids_tuple)
        ticket_id = selected_ticket_id[0]

        start_date = datetime(2024, 5, 30, 1, 1, 1, 0)
        end_date = datetime(2024, 5, 30, 12, 59, 59, 0)
        TicketGeneration = AirlineFaker.generate_random_date(start_date, end_date)
        amounts = [2000, 10000, 15000, 25000, 30000, 31000, 35000, 40000, 45000, 50000, 65000]
        amount = random.choice(amounts)
        payment_method = random.choice(["Credit Card", "Debit Card", "Cash"])

        # schedules id
        cursor.execute("SELECT Flight_id FROM Flight_Schedule")
        Flight_ids_tuple = cursor.fetchall()
        select_schd_id = random.choice(Flight_ids_tuple)
        Flight_id = select_schd_id[0]

        # Generate a random seat number
        seat_no = generate_random_seat_number(Flight_id)

        # executing the query
        cursor.execute(sql_query, (
            AirlineFaker.booking_id(),passenger_id,ticket_id,payment_method,amount,Flight_id,TicketGeneration,seat_no))
        # Commit the transaction
        conn.commit()




    def schedules_insert_data():
        # SQL query to insert data into the table
        sql_query = "INSERT INTO Flight_Schedule(Flight_id, Ac_id, Admin_id) VALUES (?, ?, ?)"

        # Select an aircraft ID from the Aircrafts table
        cursor.execute("SELECT Ac_id FROM Aircrafts")
        aircraft_ids_tuple = cursor.fetchall()
        aircraft_id = random.choice(aircraft_ids_tuple)[0]

        # Select an admin ID from the Admins table
        cursor.execute("SELECT Admin_id FROM Admins")
        admin_ids_tuple = cursor.fetchall()
        admin_id = random.choice(admin_ids_tuple)[0]

        # Generate a random departure time within a specified range
        #start_date = datetime(2024, 5, 26,1,1,1,0)
        #end_date = datetime(2024, 1, 3)
        # DepartureDate = start_date + timedelta(days=random.randint(0, (end_date - start_date).days))
        #start_date = datetime.now()
        #end_date = datetime(2024, 5, 25)
        #DepartureDate = start_date + timedelta(days=random.randint(0, (end_date - start_date).days))

        # Execute the query
        cursor.execute(sql_query,
                       (AirlineFaker.flight_id(), aircraft_id,
                        admin_id))

        # Commit the transaction
        conn.commit()
    def staff_assignments_insert_data():
        sql_query = '''
        INSERT INTO StaffAssignments (Assg_id,Staff_id, Flight_id)
        VALUES (?, ?,?);
        '''
        # Assignment ids
        assg_id = AirlineFaker.AssignmentiD()

        # unique aircraft id
        cursor.execute("SELECT Flight_id FROM Flight_Schedule ")
        fl_ids = cursor.fetchall()
        selected_tuple = random.choice(fl_ids)
        Fl_id = selected_tuple[0]

        #  staff id
        cursor.execute("SELECT Staff_id FROM Crew_Staff")
        staff_ids = cursor.fetchall()
        selected_tuple = random.choice(staff_ids)
        staff_id = selected_tuple[0]
        cursor.execute(sql_query, (assg_id, staff_id, Fl_id))
        conn.commit()


    # inserting data

    
    for _ in range(0, 100):
      bookings_insert_data()
    
    # for _ in range(0, 100):
    #   staff_assignments_insert_data()

    print("Inserted records successfully!")

except pyodbc.Error as e:
    print(f"Error: {e}")

finally:
    # Close cursor and connection
    cursor.close()
    conn.close()